module SpreeTenants
  module StoreDecorator
    def self.prepended(base)
      base.class_eval do
        # Direct ownership; the Spree join tables are mirrored from store_id.
        has_many :products, class_name: 'Spree::Product', foreign_key: :store_id, dependent: :restrict_with_error
        has_many :promotions, class_name: 'Spree::Promotion', foreign_key: :store_id, dependent: :restrict_with_error
        has_many :orders, class_name: 'Spree::Order', dependent: :restrict_with_error

        # Spree's Store#users means staff; customers live here.
        if (user_class = Spree.user_class(constantize: false)).present?
          has_many :customer_users, class_name: user_class, foreign_key: :store_id, dependent: :restrict_with_error
        end

        has_many :stock_locations, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :shipping_methods, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :zones, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :tax_categories, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :tax_rates, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :properties, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :option_types, foreign_key: :store_id, dependent: :restrict_with_error
        has_many :option_values, foreign_key: :store_id, dependent: :restrict_with_error

        validate :import_products_from_store_unsupported, on: :create
        after_create :provision_tenant_records, if: -> { SpreeTenants::Config.provision_new_stores }

        def with_tenant(&block)
          ActsAsTenant.with_tenant(self, &block)
        end

        # Relations built inside without_tenant keep the tenant-free scope.
        def all_products
          ActsAsTenant.without_tenant { Spree::Product.where(store_id: id) }
        end

        def all_orders
          ActsAsTenant.without_tenant { Spree::Order.where(store_id: id) }
        end
      end
    end

    # Staff are per store: users from another store are refused. A role from
    # another store maps to this store's role of the same name.
    def add_user(user, role = nil)
      if user.respond_to?(:store_id) && user.store_id != id
        Rails.logger.warn "[spree_tenants] refused to add #{user.class} #{user.id} (store #{user.store_id}) to store #{id}: staff are per store"
        return nil
      end

      ActsAsTenant.with_tenant(self) do
        local_role =
          if role && role.store_id != id
            Spree::Role.find_or_create_by!(name: role.name, store_id: id)
          else
            role || default_user_role
          end

        role_users.find_or_create_by!(user: user, role: local_role)
      end
    end

    def default_user_role
      ActsAsTenant.with_tenant(self) { Spree::Role.default_admin_role }
    end

    # Spree's import only inserts join rows; products belong to one store here.
    def import_products_from_store
      nil
    end

    # These answer for this store even when another store is the tenant.
    def default_shipping_category
      @default_shipping_category ||= ActsAsTenant.with_tenant(self) do
        Spree::ShippingCategory.find_or_create_by!(name: 'Default', store_id: id)
      end
    end

    def digital_shipping_category
      @digital_shipping_category ||= ActsAsTenant.with_tenant(self) do
        Spree::ShippingCategory.find_or_create_by!(name: 'Digital', store_id: id)
      end
    end

    def default_stock_location
      @default_stock_location ||= ActsAsTenant.with_tenant(self) do
        scope = Spree::StockLocation.where(default: true, store_id: id)
        scope.first || ActiveRecord::Base.connected_to(role: :writing) do
          Spree::StockLocation.find_or_create_by!(name: Spree.t(:default_stock_location_name), store_id: id) do |location|
            location.default = true
            location.active = true
            location.country = default_country
          end.tap { |location| location.update!(default: true) unless location.default? }
        end
      end
    end

    private

    # Persist a new store as its own tenant so Spree's after_create records
    # (theme, pages, taxonomies) belong to it, not to the creating request.
    def create_or_update(**options, &block)
      return super unless new_record?

      ActsAsTenant.with_tenant(self) { super }
    end

    def provision_tenant_records
      SpreeTenants::StoreProvisioner.call(self)
    end

    def import_products_from_store_unsupported
      return if import_products_from_store_id.blank?

      errors.add(:import_products_from_store_id,
                 'is not supported with spree_tenants: products belong to exactly one store. Create or copy products for the new store instead.')
    end
  end
end

Spree::Store.prepend(SpreeTenants::StoreDecorator)
