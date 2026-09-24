module SpreeTenants
  # Payment methods keep Spree's join-table ownership and are not tenant-scoped.
  module PaymentMethodDecorator
    def self.prepended(base)
      # Spree's ensure_current_store calls #store when this column is visible.
      base.ignored_columns += %w[store_id]
    end

    protected

    # Attach a new method to the tenant, not Spree::Store.default.
    def set_default_store
      return if disable_store_presence_validation?
      return if stores.any?

      stores << (ActsAsTenant.current_tenant || Spree::Store.default)
    end
  end
end

Spree::PaymentMethod.prepend(SpreeTenants::PaymentMethodDecorator)
