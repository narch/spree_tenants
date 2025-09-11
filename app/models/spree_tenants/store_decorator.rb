module SpreeTenants
  module StoreDecorator
    def self.prepended(base)
      base.class_eval do
        # Direct associations using store_id
        has_many :products, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :variants, through: :products
        has_many :orders, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :users, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :taxonomies, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :taxons, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :stock_locations, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :payment_methods, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :shipping_methods, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :zones, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :tax_categories, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :tax_rates, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :promotions, foreign_key: :store_id, dependent: :restrict_with_error
        
        # Properties and options
        has_many :properties, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :option_types, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :option_values, foreign_key: :store_id, dependent: :restrict_with_error
        
        # Scoped finder methods
        def with_tenant(&block)
          ActsAsTenant.with_tenant(self, &block)
        end
        
        # Helper to get all products for this store (bypasses current tenant)
        def all_products
          ActsAsTenant.without_tenant { products }
        end
        
        # Helper to get all orders for this store (bypasses current tenant)  
        def all_orders
          ActsAsTenant.without_tenant { orders }
        end
      end
    end
    
    # Override shipping category methods to ensure store_id is set
    def default_shipping_category
      @default_shipping_category ||= Spree::ShippingCategory.find_or_create_by(
        name: 'Default',
        store_id: id
      )
    end
    
    def digital_shipping_category
      @digital_shipping_category ||= Spree::ShippingCategory.find_or_create_by(
        name: 'Digital', 
        store_id: id
      )
    end
    
    # Override default stock location to ensure store_id is set
    def default_stock_location
      @default_stock_location ||= begin
        stock_location_scope = Spree::StockLocation.where(default: true, store_id: id)
        stock_location_scope.first || ActiveRecord::Base.connected_to(role: :writing) do
          stock_location_scope.create(
            default: true,
            name: Spree.t(:default_stock_location_name),
            country: default_country,
            store_id: id
          )
        end
      end
    end
  end
end

Spree::Store.prepend(SpreeTenants::StoreDecorator)