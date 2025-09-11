class AddStoreScopedMultiTenancy < ActiveRecord::Migration[7.0]
  def up
    # ============ 1) Add store_id to tables ============

    core_tables = %i[
      spree_products
      spree_variants
      spree_product_properties
      spree_product_option_types
      spree_option_values
      spree_option_types
      spree_properties

      spree_taxonomies
      spree_taxons

      spree_orders
      spree_line_items
      spree_shipments
      spree_payments
      spree_adjustments
      spree_return_authorizations

      spree_stock_locations
      spree_stock_items
      spree_stock_movements

      spree_payment_methods
      spree_shipping_methods
      spree_shipping_categories
      spree_tax_categories
      spree_tax_rates
      spree_zones
      spree_zone_members

      spree_promotions
      spree_promotion_rules
      spree_promotion_actions

      spree_users
      spree_admin_users
    ]

    legacy_plus_useful = %i[
      spree_addresses
      spree_assets
      spree_calculators
      spree_coupon_codes
      spree_credit_cards
      spree_customer_returns
      spree_digital_links
      spree_gateways
      spree_inventory_units
      spree_log_entries
      spree_payment_capture_events
      spree_preferences
      spree_prototypes
      spree_property_prototypes
      spree_option_type_prototypes
      spree_prototype_taxons
      spree_roles
      spree_role_users
      spree_shipping_method_categories
      spree_shipping_rates
      spree_state_changes
      spree_trackers
      spree_promotion_action_line_items
      # Countries/States: include only if you want per-store copies; otherwise skip.
      # spree_countries
      # spree_states
    ]

    join_tables = %i[
      spree_products_taxons
      spree_option_value_variants
      spree_shipping_method_zones
      spree_products_promotion_rules
      # If your app uses other join tables, add them here.
    ]

    (core_tables + legacy_plus_useful + join_tables).each { |t| add_store_ref(t) }

    # ============ 2) Backfill store_id via parents where obvious ============

    # inventory_units -> orders
    backfill_via_parent :spree_inventory_units, :order_id, :spree_orders
    # shipping_rates -> shipments -> orders
    backfill_via_parent :spree_shipping_rates, :shipment_id, :spree_shipments
    # payment_capture_events -> payments -> orders
    backfill_via_parent :spree_payment_capture_events, :payment_id, :spree_payments

    # line_items -> orders
    backfill_via_parent :spree_line_items, :order_id, :spree_orders
    # shipments -> orders
    backfill_via_parent :spree_shipments, :order_id, :spree_orders
    # payments -> orders
    backfill_via_parent :spree_payments, :order_id, :spree_orders
    # adjustments -> orders
    backfill_via_parent :spree_adjustments, :order_id, :spree_orders

    # product-side tables -> products
    backfill_via_parent :spree_variants, :product_id, :spree_products
    backfill_via_parent :spree_product_properties, :product_id, :spree_products
    backfill_via_parent :spree_product_option_types, :product_id, :spree_products

    # taxonomy/taxons -> taxonomies (if present)
    backfill_via_parent :spree_taxons, :taxonomy_id, :spree_taxonomies

    # stock_items -> stock_locations
    backfill_via_parent :spree_stock_items, :stock_location_id, :spree_stock_locations
    # stock_movements -> stock_items
    if table_exists?(:spree_stock_movements) && column_exists?(:spree_stock_movements, :stock_item_id)
      backfill_sql <<~SQL
        UPDATE spree_stock_movements
        SET store_id = (
          SELECT store_id FROM spree_stock_items WHERE spree_stock_items.id = spree_stock_movements.stock_item_id
        )
        WHERE spree_stock_movements.store_id IS NULL AND spree_stock_movements.stock_item_id IS NOT NULL;
      SQL
    end

    # promotion_actions -> promotions
    backfill_via_parent :spree_promotion_actions, :promotion_id, :spree_promotions
    # promotion_rules -> promotions
    backfill_via_parent :spree_promotion_rules, :promotion_id, :spree_promotions
    # promotion_action_line_items -> promotion_actions
    backfill_via_parent :spree_promotion_action_line_items, :promotion_action_id, :spree_promotion_actions

    # zone_members -> zones
    backfill_via_parent :spree_zone_members, :zone_id, :spree_zones
    # tax_rates -> tax_categories
    backfill_via_parent :spree_tax_rates, :tax_category_id, :spree_tax_categories

    # shipping_method_categories -> shipping_methods
    backfill_via_parent :spree_shipping_method_categories, :shipping_method_id, :spree_shipping_methods

    # products_taxons join
    if table_exists?(:spree_products_taxons)
      backfill_sql <<~SQL
        UPDATE spree_products_taxons
        SET store_id = (
          SELECT store_id FROM spree_products WHERE spree_products.id = spree_products_taxons.product_id
        )
        WHERE spree_products_taxons.store_id IS NULL AND spree_products_taxons.product_id IS NOT NULL;
      SQL
    end

    # option_value_variants join
    if table_exists?(:spree_option_value_variants)
      backfill_sql <<~SQL
        UPDATE spree_option_value_variants
        SET store_id = (
          SELECT store_id FROM spree_variants WHERE spree_variants.id = spree_option_value_variants.variant_id
        )
        WHERE spree_option_value_variants.store_id IS NULL AND spree_option_value_variants.variant_id IS NOT NULL;
      SQL
    end

    # shipping_method_zones join
    if table_exists?(:spree_shipping_method_zones)
      backfill_sql <<~SQL
        UPDATE spree_shipping_method_zones
        SET store_id = (
          SELECT store_id FROM spree_shipping_methods WHERE spree_shipping_methods.id = spree_shipping_method_zones.shipping_method_id
        )
        WHERE spree_shipping_method_zones.store_id IS NULL AND spree_shipping_method_zones.shipping_method_id IS NOT NULL;
      SQL
    end

    # products_promotion_rules join
    if table_exists?(:spree_products_promotion_rules)
      backfill_sql <<~SQL
        UPDATE spree_products_promotion_rules
        SET store_id = (
          SELECT store_id FROM spree_products WHERE spree_products.id = spree_products_promotion_rules.product_id
        )
        WHERE spree_products_promotion_rules.store_id IS NULL AND spree_products_promotion_rules.product_id IS NOT NULL;
      SQL
    end

    # addresses -> users (if you want to inherit; otherwise leave NULL)
    if column_exists?(:spree_addresses, :user_id)
      backfill_sql <<~SQL
        UPDATE spree_addresses
        SET store_id = (
          SELECT store_id FROM spree_users WHERE spree_users.id = spree_addresses.user_id
        )
        WHERE spree_addresses.store_id IS NULL AND spree_addresses.user_id IS NOT NULL;
      SQL
    end

    # credit_cards -> users
    if column_exists?(:spree_credit_cards, :user_id)
      backfill_sql <<~SQL
        UPDATE spree_credit_cards
        SET store_id = (
          SELECT store_id FROM spree_users WHERE spree_users.id = spree_credit_cards.user_id
        )
        WHERE spree_credit_cards.store_id IS NULL AND spree_credit_cards.user_id IS NOT NULL;
      SQL
    end

    # ============ 3) Replace/augment indexes to be store-scoped ============

    # Products: slug unique per store
    safe_remove_index :spree_products, [:slug]
    add_index :spree_products, [:store_id, :slug], unique: true, if_not_exists: true
    add_index :spree_products, [:store_id, :available_on], if_not_exists: true

    # Orders: number globally unique (not per store), plus useful filter
    # Keep the original unique index on number
    # safe_remove_index :spree_orders, [:number] # Don't remove, keep globally unique
    add_index :spree_orders, [:store_id, :completed_at], if_not_exists: true
    add_index :spree_orders, [:store_id], if_not_exists: true

    # Users: email unique per store (opt-in)
    safe_remove_index :spree_users, [:email]
    add_index :spree_users, [:store_id, :email], unique: true, if_not_exists: true

    # Variants: sku (if globally unique) -> per store
    if index_exists?(:spree_variants, [:sku])
      safe_remove_index :spree_variants, [:sku]
      add_index :spree_variants, [:store_id, :sku], unique: true, if_not_exists: true
    end

    # ProductsTaxons join: unique per store/product/taxon
    safe_remove_index :spree_products_taxons, [:product_id, :taxon_id]
    add_index :spree_products_taxons, [:store_id, :product_id, :taxon_id],
              unique: true, if_not_exists: true, name: 'idx_products_taxons_store_product_taxon'

    # ShippingRates join: unique per store/shipment/method
    safe_remove_index :spree_shipping_rates, [:shipment_id, :shipping_method_id]
    add_index :spree_shipping_rates, [:store_id, :shipment_id, :shipping_method_id],
              unique: true, if_not_exists: true, name: 'idx_shipping_rates_store_shipment_method'

    # ShippingMethodCategories join
    safe_remove_index :spree_shipping_method_categories, [:shipping_method_id, :shipping_category_id]
    add_index :spree_shipping_method_categories, [:store_id, :shipping_method_id, :shipping_category_id],
              unique: true, name: "uniq_smcat_store_method_category", if_not_exists: true

    # OptionValueVariants join
    if table_exists?(:spree_option_value_variants)
      safe_remove_index :spree_option_value_variants, [:variant_id, :option_value_id]
      add_index :spree_option_value_variants, [:store_id, :variant_id, :option_value_id],
                unique: true, if_not_exists: true, name: 'idx_opt_val_vars_store_variant_option'
    end

    # Roles (if you want different role names per store)
    if table_exists?(:spree_roles)
      safe_remove_index :spree_roles, [:name]
      add_index :spree_roles, [:store_id, :name], unique: true, if_not_exists: true
    end

    # Trackers: make analytics id unique per store if needed
    if table_exists?(:spree_trackers) && column_exists?(:spree_trackers, :analytics_id)
      add_index :spree_trackers, [:store_id, :analytics_id], unique: true, if_not_exists: true
    end

    # Gateways / PaymentMethods: common lookups
    add_index :spree_payment_methods, [:store_id, :type], if_not_exists: true
    add_index :spree_gateways,        [:store_id, :type], if_not_exists: true if table_exists?(:spree_gateways)
  end

  def down
    # Best-effort rollback: drop the store-scoped indexes we created,
    # re-create original globals where they likely existed, and remove store_id.

    # Index rollbacks (safe)
    safe_remove_index :spree_products, [:store_id, :slug]
    add_index :spree_products, [:slug], unique: true, if_not_exists: true

    # Orders: number was kept globally unique, no need to re-add
    safe_remove_index :spree_orders, [:store_id, :completed_at]
    safe_remove_index :spree_orders, [:store_id]

    safe_remove_index :spree_users, [:store_id, :email]
    add_index :spree_users, [:email], unique: true, if_not_exists: true

    if index_exists?(:spree_variants, [:store_id, :sku])
      safe_remove_index :spree_variants, [:store_id, :sku]
      add_index :spree_variants, [:sku], unique: true, if_not_exists: true
    end

    safe_remove_index :spree_products_taxons, [:store_id, :product_id, :taxon_id]
    add_index :spree_products_taxons, [:product_id, :taxon_id], unique: true, if_not_exists: true

    safe_remove_index :spree_shipping_rates, [:store_id, :shipment_id, :shipping_method_id]
    add_index :spree_shipping_rates, [:shipment_id, :shipping_method_id], unique: true, if_not_exists: true

    safe_remove_index :spree_shipping_method_categories, name: "uniq_smcat_store_method_category"
    add_index :spree_shipping_method_categories, [:shipping_method_id, :shipping_category_id], unique: true, if_not_exists: true

    if table_exists?(:spree_option_value_variants)
      safe_remove_index :spree_option_value_variants, [:store_id, :variant_id, :option_value_id]
      add_index :spree_option_value_variants, [:variant_id, :option_value_id], unique: true, if_not_exists: true
    end

    if table_exists?(:spree_roles)
      safe_remove_index :spree_roles, [:store_id, :name]
      add_index :spree_roles, [:name], unique: true, if_not_exists: true
    end

    safe_remove_index :spree_trackers, [:store_id, :analytics_id] if table_exists?(:spree_trackers)

    # Remove store_id columns (safe, only if exists)
    (all_tables_for_store_ref).each do |t|
      if table_exists?(t) && column_exists?(t, :store_id)
        remove_reference t, :store, foreign_key: { to_table: :spree_stores }
      end
    end
  end

  private

  # --- helpers ---

  def add_store_ref(table)
    return unless table_exists?(table)
    return if column_exists?(table, :store_id)

    add_reference table, :store, foreign_key: { to_table: :spree_stores }, index: true
  end

  # Backfill child.store_id from parent.store_id via child.fk_column
  # Works without vendor-specific SQL; uses a correlated subquery.
  def backfill_via_parent(child_table, fk_column, parent_table)
    return unless table_exists?(child_table) && table_exists?(parent_table)
    return unless column_exists?(child_table, fk_column) && column_exists?(parent_table, :store_id)
    execute <<~SQL
      UPDATE #{child_table}
      SET store_id = (
        SELECT store_id FROM #{parent_table} WHERE #{parent_table}.id = #{child_table}.#{fk_column}
      )
      WHERE #{child_table}.store_id IS NULL AND #{child_table}.#{fk_column} IS NOT NULL;
    SQL
  end

  # Execute raw SQL only if the table exists; pass a string.
  def backfill_sql(sql = nil, &blk)
    execute(sql || blk.call)
  end

  def safe_remove_index(table, cols_or_name)
    return unless table_exists?(table)
    if cols_or_name.is_a?(Array)
      remove_index table, column: cols_or_name, if_exists: true
    else
      remove_index table, name: cols_or_name, if_exists: true
    end
  end

  def all_tables_for_store_ref
    %i[
      spree_products
      spree_variants
      spree_product_properties
      spree_product_option_types
      spree_option_values
      spree_option_types
      spree_properties
      spree_taxonomies
      spree_taxons
      spree_orders
      spree_line_items
      spree_shipments
      spree_payments
      spree_adjustments
      spree_return_authorizations
      spree_stock_locations
      spree_stock_items
      spree_stock_movements
      spree_payment_methods
      spree_shipping_methods
      spree_shipping_categories
      spree_tax_categories
      spree_tax_rates
      spree_zones
      spree_zone_members
      spree_promotions
      spree_promotion_rules
      spree_promotion_actions
      spree_users
      spree_admin_users
      spree_addresses
      spree_assets
      spree_calculators
      spree_credit_cards
      spree_gateways
      spree_inventory_units
      spree_log_entries
      spree_payment_capture_events
      spree_preferences
      spree_prototypes
      spree_property_prototypes
      spree_option_type_prototypes
      spree_prototype_taxons
      spree_roles
      spree_role_users
      spree_shipping_method_categories
      spree_shipping_rates
      spree_state_changes
      spree_trackers
      spree_promotion_action_line_items
      spree_products_taxons
      spree_option_value_variants
      spree_shipping_method_zones
      spree_products_promotion_rules
    ]
  end
end