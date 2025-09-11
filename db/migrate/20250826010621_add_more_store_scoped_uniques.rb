class AddMoreStoreScopedUniques < ActiveRecord::Migration[7.0]
  def up
    # ---------- Products ----------
    replace_unique_index :spree_products,
      old:  { columns: [:slug] },
      new:  { columns: [:store_id, :slug], name: "idx_products_store_slug" }

    add_index :spree_products,
      [:store_id, :available_on],
      name: "idx_products_store_available_on",
      if_not_exists: true

    # ---------- Orders ----------
    replace_unique_index :spree_orders,
      old:  { columns: [:number] },
      new:  { columns: [:store_id, :number], name: "idx_orders_store_number" }

    add_index :spree_orders,
      [:store_id, :completed_at],
      name: "idx_orders_store_completed_at",
      if_not_exists: true

    # ---------- Users (if users are not shared) ----------
    if column_exists?(:spree_users, :store_id)
      replace_unique_index :spree_users,
        old:  { columns: [:email] },
        new:  { columns: [:store_id, :email], name: "idx_users_store_email" }
    end

    # ---------- Variants (SKU scoping if you want per-store uniqueness) ----------
    if index_exists?(:spree_variants, [:sku])
      replace_unique_index :spree_variants,
        old:  { columns: [:sku] },
        new:  { columns: [:store_id, :sku], name: "idx_variants_store_sku" }
    else
      # If there wasn't a global unique, add a store-scoped unique if that’s desired.
      add_index :spree_variants, [:store_id, :sku],
        unique: true,
        name: "idx_variants_store_sku",
        if_not_exists: true
    end

    # ---------- Products ↔ Taxons ----------
    if table_exists?(:spree_products_taxons)
      replace_unique_index :spree_products_taxons,
        old:  { columns: [:product_id, :taxon_id] },
        new:  { columns: [:store_id, :product_id, :taxon_id], name: "idx_prod_taxons_store_prod_taxon" }
    end

    # ---------- Shipping Rates ----------
    if table_exists?(:spree_shipping_rates)
      replace_unique_index :spree_shipping_rates,
        old:  { columns: [:shipment_id, :shipping_method_id] },
        new:  { columns: [:store_id, :shipment_id, :shipping_method_id], name: "idx_ship_rates_store_ship_method" }
    end

    # ---------- Shipping Method Categories ----------
    if table_exists?(:spree_shipping_method_categories)
      replace_unique_index :spree_shipping_method_categories,
        old:  { columns: [:shipping_method_id, :shipping_category_id] },
        new:  { columns: [:store_id, :shipping_method_id, :shipping_category_id], name: "idx_smcat_store_method_cat" }
    end

    # ---------- Option Value Variants (join) ----------
    if table_exists?(:spree_option_value_variants)
      replace_unique_index :spree_option_value_variants,
        old:  { columns: [:variant_id, :option_value_id] },
        new:  { columns: [:store_id, :variant_id, :option_value_id], name: "idx_ovv_store_variant_opt" }
    end

    # ---------- Roles (only if roles are per-store for your OSS defaults) ----------
    if table_exists?(:spree_roles) && column_exists?(:spree_roles, :store_id)
      replace_unique_index :spree_roles,
        old:  { columns: [:name] },
        new:  { columns: [:store_id, :name], name: "idx_roles_store_name" }
    end

    # ---------- Taxonomies (if you want unique names per store) ----------
    if table_exists?(:spree_taxonomies) && column_exists?(:spree_taxonomies, :store_id)
      add_index :spree_taxonomies, [:store_id, :name],
        unique: true,
        name: "idx_taxonomies_store_name",
        if_not_exists: true
    end

    # ---------- Shipments / Payments numbers (helpful in many stores) ----------
    if table_exists?(:spree_shipments) && column_exists?(:spree_shipments, :number)
      add_unique_if_absent :spree_shipments, [:store_id, :number], "idx_shipments_store_number"
    end

    if table_exists?(:spree_payments) && column_exists?(:spree_payments, :number)
      add_unique_if_absent :spree_payments, [:store_id, :number], "idx_payments_store_number"
    end

    # ---------- Trackers (optional: analytics id per store) ----------
    if table_exists?(:spree_trackers) && column_exists?(:spree_trackers, :analytics_id)
      add_index :spree_trackers, [:store_id, :analytics_id],
        unique: true,
        name: "idx_trackers_store_analytics",
        if_not_exists: true
    end
  end

  def down
    # Revert the ones we explicitly created or replaced above.
    safe_remove_index :spree_products, name: "idx_products_store_slug"
    add_index :spree_products, [:slug], unique: true, if_not_exists: true
    safe_remove_index :spree_products, name: "idx_products_store_available_on"

    safe_remove_index :spree_orders, name: "idx_orders_store_number"
    add_index :spree_orders, [:number], unique: true, if_not_exists: true
    safe_remove_index :spree_orders, name: "idx_orders_store_completed_at"

    safe_remove_index :spree_users,   name: "idx_users_store_email"   if table_exists?(:spree_users)

    if index_exists?(:spree_variants, name: "idx_variants_store_sku")
      safe_remove_index :spree_variants, name: "idx_variants_store_sku"
      # restore global unique if it existed originally
      add_index :spree_variants, [:sku], unique: true, if_not_exists: true
    end

    safe_remove_index :spree_products_taxons, name: "idx_prod_taxons_store_prod_taxon"
    add_index :spree_products_taxons, [:product_id, :taxon_id], unique: true, if_not_exists: true

    safe_remove_index :spree_shipping_rates, name: "idx_ship_rates_store_ship_method"
    add_index :spree_shipping_rates, [:shipment_id, :shipping_method_id], unique: true, if_not_exists: true

    safe_remove_index :spree_shipping_method_categories, name: "idx_smcat_store_method_cat"
    add_index :spree_shipping_method_categories, [:shipping_method_id, :shipping_category_id], unique: true, if_not_exists: true

    safe_remove_index :spree_option_value_variants, name: "idx_ovv_store_variant_opt" if table_exists?(:spree_option_value_variants)
    add_index :spree_option_value_variants, [:variant_id, :option_value_id], unique: true, if_not_exists: true

    safe_remove_index :spree_roles, name: "idx_roles_store_name" if table_exists?(:spree_roles)
    add_index :spree_roles, [:name], unique: true, if_not_exists: true

    safe_remove_index :spree_taxonomies, name: "idx_taxonomies_store_name" if table_exists?(:spree_taxonomies)

    safe_remove_index :spree_shipments, name: "idx_shipments_store_number" if table_exists?(:spree_shipments)
    safe_remove_index :spree_payments,  name: "idx_payments_store_number"  if table_exists?(:spree_payments)

    safe_remove_index :spree_trackers, name: "idx_trackers_store_analytics" if table_exists?(:spree_trackers)
  end

  private

  # Replace an existing unique index (by columns) with a store-scoped unique index.
  # Falls back gracefully if the old index doesn’t exist.
  def replace_unique_index(table, old:, new:)
    return unless table_exists?(table)
    safe_remove_index table, columns: old[:columns], name: old[:name]
    add_index table, new[:columns], unique: true, name: new[:name], if_not_exists: true
  end

  # Remove index by name or columns if exists (safe across DBs).
  def safe_remove_index(table, columns: nil, name: nil)
    return unless table_exists?(table)
    if name
      remove_index table, name: name, if_exists: true
    elsif columns
      remove_index table, column: columns, if_exists: true
    end
  end

  # Add a unique index only if an identical one isn’t already present.
  def add_unique_if_absent(table, cols, name)
    return unless table_exists?(table)
    add_index table, cols, unique: true, name: name, if_not_exists: true
  end
end
