# Reconciles store ownership after the multi-tenancy audit:
# - drops the store-1 defaults on store_id columns
# - moves payment methods to Spree's join-table ownership
# - backfills the product/promotion join tables from store_id
# - adds per-store, case-insensitive unique indexes on names, emails and SKUs
# - scopes staff invitations
#
# Requires PostgreSQL or SQLite (expression and partial indexes).
class ReconcileStoreOwnership < ActiveRecord::Migration[8.0]
  SUPPORTED_ADAPTERS = %w[PostgreSQL SQLite].freeze

  DEFAULTED_TABLES = %i[
    spree_pages
    spree_page_blocks
    spree_page_links
    spree_page_sections
    spree_refund_reasons
    spree_reimbursement_types
    spree_return_authorization_reasons
    spree_store_credit_categories
    spree_store_credit_types
    spree_webhooks_events
    spree_webhooks_subscribers
    spree_promotion_categories
    spree_stock_transfers
    spree_digitals
  ].freeze

  GLOBAL_NAME_INDEXES = {
    spree_refund_reasons: 'index_spree_refund_reasons_on_name',
    spree_reimbursement_types: 'index_spree_reimbursement_types_on_name',
    spree_return_authorization_reasons: 'index_spree_return_authorization_reasons_on_name'
  }.freeze

  STORE_SCOPED_NAME_TABLES = %i[
    spree_refund_reasons
    spree_reimbursement_types
    spree_return_authorization_reasons
    spree_store_credit_categories
    spree_store_credit_types
    spree_promotion_categories
  ].freeze

  SKU_INDEX = 'index_spree_variants_on_store_id_and_lower_sku_active'.freeze

  CASE_INSENSITIVE_NAME_TABLES = %i[
    spree_refund_reasons
    spree_reimbursement_types
    spree_return_authorization_reasons
    spree_store_credit_categories
    spree_store_credit_types
    spree_promotion_categories
    spree_zones
    spree_tax_categories
    spree_stock_locations
    spree_shipping_categories
    spree_roles
    spree_properties
    spree_option_types
  ].freeze

  USER_TABLES = %i[spree_users spree_admin_users].freeze

  LEGACY_DUPLICATE_INDEXES = {
    spree_users: ['idx_users_store_email', [:store_id, :email]],
    spree_roles: ['idx_roles_store_name', [:store_id, :name]],
    spree_products: ['idx_products_store_slug', [:store_id, :slug]]
  }.freeze

  def up
    ensure_supported_adapter!
    ensure_no_case_insensitive_duplicates!

    DEFAULTED_TABLES.each do |table|
      next unless store_id_column?(table)

      change_column_default table, :store_id, from: 1, to: nil
    end

    GLOBAL_NAME_INDEXES.each do |table, index_name|
      remove_index table, name: index_name, if_exists: true if table_exists?(table)
    end

    STORE_SCOPED_NAME_TABLES.each do |table|
      next unless store_id_column?(table)

      add_index table, [:store_id, :name], unique: true, if_not_exists: true
    end

    if store_id_column?(:spree_payment_methods) && table_exists?(:spree_payment_methods_stores)
      change_column_null :spree_payment_methods, :store_id, true

      execute <<~SQL.squish
        INSERT INTO spree_payment_methods_stores (payment_method_id, store_id)
        SELECT pm.id, pm.store_id
        FROM spree_payment_methods pm
        WHERE pm.store_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM spree_payment_methods_stores pms
            WHERE pms.payment_method_id = pm.id AND pms.store_id = pm.store_id
          )
      SQL
    end

    sync_join_table(:spree_products_stores, :product_id, :spree_products)
    sync_join_table(:spree_promotions_stores, :promotion_id, :spree_promotions)

    if store_id_column?(:spree_variants) && column_exists?(:spree_variants, :sku)
      add_index :spree_variants, 'store_id, lower(sku)',
                unique: true,
                where: "deleted_at IS NULL AND sku <> ''",
                name: SKU_INDEX,
                if_not_exists: true
    end

    CASE_INSENSITIVE_NAME_TABLES.each { |table| add_case_insensitive_name_index(table) }

    if table_exists?(:spree_invitations)
      unless column_exists?(:spree_invitations, :store_id)
        add_column :spree_invitations, :store_id, :bigint
        add_index :spree_invitations, :store_id
        add_foreign_key :spree_invitations, :spree_stores, column: :store_id
      end

      execute <<~SQL.squish
        UPDATE spree_invitations SET store_id = resource_id WHERE resource_type = 'Spree::Store' AND store_id IS NULL
      SQL

      leftovers = select_value('SELECT COUNT(*) FROM spree_invitations WHERE store_id IS NULL').to_i
      raise ActiveRecord::MigrationError, "#{leftovers} spree_invitations rows have a non-store resource; assign store_id manually first" if leftovers.positive?

      change_column_null :spree_invitations, :store_id, false
    end

    # Assets created outside a tenant context have no store; derive it from
    # the variant or taxon they are attached to.
    if store_id_column?(:spree_assets)
      { 'Spree::Variant' => :spree_variants, 'Spree::Taxon' => :spree_taxons }.each do |viewable_type, table|
        next unless store_id_column?(table)

        execute <<~SQL.squish
          UPDATE spree_assets SET store_id = (
            SELECT v.store_id FROM #{table} v WHERE v.id = spree_assets.viewable_id
          )
          WHERE spree_assets.store_id IS NULL AND spree_assets.viewable_type = '#{viewable_type}'
        SQL
      end
    end

    add_index :spree_products_stores, [:product_id, :store_id], unique: true, if_not_exists: true if table_exists?(:spree_products_stores)
    add_index :spree_promotions_stores, [:promotion_id, :store_id], unique: true, if_not_exists: true if table_exists?(:spree_promotions_stores)

    USER_TABLES.each do |table|
      next unless store_id_column?(table) && column_exists?(table, :email)

      remove_index table, name: "index_#{table}_on_email", if_exists: true
      add_index table, 'store_id, lower(email)',
                unique: true,
                where: [("deleted_at IS NULL" if column_exists?(table, :deleted_at)), "email <> ''"].compact.join(' AND '),
                name: "idx_#{table.to_s.delete_prefix('spree_')}_store_lower_email",
                if_not_exists: true
    end

    # Earlier migrations created these twice under different names.
    LEGACY_DUPLICATE_INDEXES.each do |table, (legacy_name, columns)|
      next unless table_exists?(table) && index_exists?(table, columns) && index_name_exists?(table, legacy_name)

      remove_index table, name: legacy_name
    end
  end

  def down
    ensure_payment_methods_reducible_to_one_store!

    remove_index :spree_variants, name: SKU_INDEX, if_exists: true if table_exists?(:spree_variants)
    remove_column :spree_invitations, :store_id if table_exists?(:spree_invitations) && column_exists?(:spree_invitations, :store_id)

    USER_TABLES.each do |table|
      remove_index table, name: "idx_#{table.to_s.delete_prefix('spree_')}_store_lower_email", if_exists: true if table_exists?(table)
    end

    CASE_INSENSITIVE_NAME_TABLES.each do |table|
      remove_index table, name: case_insensitive_name_index(table), if_exists: true if table_exists?(table)
    end

    DEFAULTED_TABLES.each do |table|
      next unless store_id_column?(table)

      change_column_default table, :store_id, from: nil, to: 1
    end

    if store_id_column?(:spree_payment_methods) && table_exists?(:spree_payment_methods_stores)
      execute <<~SQL.squish
        UPDATE spree_payment_methods SET store_id = (
          SELECT MIN(store_id) FROM spree_payment_methods_stores
          WHERE spree_payment_methods_stores.payment_method_id = spree_payment_methods.id
        ) WHERE store_id IS NULL
      SQL

      change_column_null :spree_payment_methods, :store_id, false
    end

    # Global name/email indexes are not restored (per-store duplicates may
    # exist); the join-table backfill is not undone.
  end

  private

  # Rolling back returns payment methods to single-store ownership; refuse
  # while any method is unassigned or shared.
  def ensure_payment_methods_reducible_to_one_store!
    return unless store_id_column?(:spree_payment_methods) && table_exists?(:spree_payment_methods_stores)

    ambiguous = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM spree_payment_methods pm
      WHERE pm.store_id IS NULL
        AND (
          SELECT COUNT(DISTINCT pms.store_id)
          FROM spree_payment_methods_stores pms
          WHERE pms.payment_method_id = pm.id
        ) <> 1
    SQL
    return unless ambiguous.positive?

    raise ActiveRecord::IrreversibleMigration,
          "#{ambiguous} payment methods cannot be reduced to one store; assign unassigned methods or split shared methods before rolling back"
  end

  def store_id_column?(table)
    table_exists?(table) && column_exists?(table, :store_id)
  end

  # Report every case-insensitive duplicate before any DDL runs.
  def ensure_no_case_insensitive_duplicates!
    checks = CASE_INSENSITIVE_NAME_TABLES.map { |table| [table, :name] } +
             USER_TABLES.map { |table| [table, :email] } +
             [[:spree_variants, :sku]]

    offenders = checks.flat_map do |table, column|
      next [] unless store_id_column?(table) && column_exists?(table, column)

      conditions = ["#{column} <> ''"]
      conditions << 'deleted_at IS NULL' if column_exists?(table, :deleted_at)
      select_rows(<<~SQL.squish).map { |store_id, value, count| "#{table}: store #{store_id} #{column}=#{value.inspect} x#{count}" }
        SELECT store_id, lower(#{column}), COUNT(*) FROM #{table}
        WHERE #{conditions.join(' AND ')}
        GROUP BY store_id, lower(#{column}) HAVING COUNT(*) > 1
      SQL
    end

    return if offenders.empty?

    raise ActiveRecord::MigrationError,
          "Case-insensitive duplicates must be resolved before adding per-store unique indexes:\n  #{offenders.join("\n  ")}"
  end

  def ensure_supported_adapter!
    adapter = connection.adapter_name
    return if SUPPORTED_ADAPTERS.any? { |name| adapter.start_with?(name) }

    raise ActiveRecord::MigrationError,
          "#{self.class.name} needs expression and partial unique indexes and supports #{SUPPORTED_ADAPTERS.join(', ')}; " \
          "got #{adapter}. For MySQL, add generated columns (lower(name), lower(sku), active flag) and index those instead."
  end

  def case_insensitive_name_index(table)
    "idx_#{table.to_s.delete_prefix('spree_')}_store_lower_name"
  end

  def add_case_insensitive_name_index(table)
    return unless store_id_column?(table) && column_exists?(table, :name)

    add_index table, 'store_id, lower(name)',
              unique: true,
              where: (column_exists?(table, :deleted_at) ? 'deleted_at IS NULL' : nil),
              name: case_insensitive_name_index(table),
              if_not_exists: true
  end

  def sync_join_table(join_table, owner_fk, owner_table)
    return unless table_exists?(join_table) && store_id_column?(owner_table)

    execute <<~SQL.squish
      DELETE FROM #{join_table}
      WHERE EXISTS (
        SELECT 1 FROM #{owner_table} o
        WHERE o.id = #{join_table}.#{owner_fk}
          AND o.store_id IS NOT NULL
          AND o.store_id <> #{join_table}.store_id
      )
    SQL

    execute <<~SQL.squish
      INSERT INTO #{join_table} (#{owner_fk}, store_id, created_at, updated_at)
      SELECT o.id, o.store_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM #{owner_table} o
      WHERE o.store_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM #{join_table} j
          WHERE j.#{owner_fk} = o.id AND j.store_id = o.store_id
        )
    SQL
  end
end
