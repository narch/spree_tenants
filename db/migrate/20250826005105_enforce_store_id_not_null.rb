class EnforceStoreIdNotNull < ActiveRecord::Migration[7.0]
  def up
    # Pick the tables that MUST belong to a store to keep data isolation clean.
    required = %i[
      spree_admin_users
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

      # explicitly store-scoped auth
      spree_users
      spree_roles

      # common joins that should be store-scoped
      spree_products_taxons
      spree_shipping_method_categories
      spree_shipping_rates
      spree_option_value_variants
      spree_promotion_action_line_items
    ]

    required.each { |t| make_not_null(t, :store_id) }

    # Ensure the scoped uniques exist (in case someone’s on a quirky schema).
    add_index :spree_products, [:store_id, :slug], unique: true, if_not_exists: true
    add_index :spree_users,    [:store_id, :email],   unique: true, if_not_exists: true

    # If you decided to scope SKUs per store:
    if table_exists?(:spree_variants) && column_exists?(:spree_variants, :sku)
      remove_index :spree_variants, [:sku], if_exists: true
      add_index    :spree_variants, [:store_id, :sku], unique: true, if_not_exists: true
    end

    # Roles: names unique within a store
    if table_exists?(:spree_roles)
      remove_index :spree_roles, [:name], if_exists: true
      add_index    :spree_roles, [:store_id, :name], unique: true, if_not_exists: true
    end

    # Tighten role assignment uniqueness to be store-aware
    if table_exists?(:spree_role_users)
      remove_index :spree_role_users,
                   name: "idx_role_users_store_resource_user_role",
                   if_exists: true
      add_index :spree_role_users,
                [:store_id, :resource_id, :resource_type, :user_id, :user_type, :role_id],
                unique: true,
                name: "idx_role_users_store_resource_user_role",
                if_not_exists: true
    end
  end

  def down
    # Loosen NOT NULL (rollback)
    required = %i[
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
      spree_roles
      spree_products_taxons
      spree_shipping_method_categories
      spree_shipping_rates
      spree_option_value_variants
      spree_promotion_action_line_items
    ]
    required.each { |t| make_nullable(t, :store_id) }

    # (Indexes left in place on rollback; safe to keep.)
  end

  private

  def make_not_null(table, column)
    return unless table_exists?(table) && column_exists?(table, column)
    change_column_null table, column, false
  end

  def make_nullable(table, column)
    return unless table_exists?(table) && column_exists?(table, column)
    change_column_null table, column, true
  end
end

