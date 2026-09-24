module SpreeTenants
  # Spree::Store.current and Spree::Current.store answer with the default store;
  # when a tenant is set, it is the current store.
  module CurrentStoreDecorator
    module StoreClassMethods
      def current(url = nil)
        return super if url.present?

        tenant = ActsAsTenant.current_tenant
        return tenant if tenant.is_a?(Spree::Store) && tenant.persisted?

        super
      end
    end

    module CurrentAttributes
      def store
        tenant = ActsAsTenant.current_tenant
        return tenant if tenant.is_a?(Spree::Store) && tenant.persisted?

        super
      end
    end
  end
end

Spree::Store.singleton_class.prepend(SpreeTenants::CurrentStoreDecorator::StoreClassMethods)
Spree::Current.prepend(SpreeTenants::CurrentStoreDecorator::CurrentAttributes)
