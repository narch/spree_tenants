module Spree
  # Pins the tenant to current_store for storefront and admin requests, before
  # any subclass callback (including admin authorization).
  module BaseControllerDecorator
    def self.prepended(base)
      base.prepend_around_action :scope_request_to_current_store
    end

    private

    def scope_request_to_current_store(&block)
      SpreeTenants::TenantScoping.ensure_applied!
      @current_store ||= request.env[SpreeTenants::CurrentStoreMiddleware::ENV_KEY] if request.env.key?(SpreeTenants::CurrentStoreMiddleware::ENV_KEY)

      store = current_store
      store = nil unless store&.persisted?
      ActsAsTenant.with_tenant(store, &block)
    end
  end
end

Spree::BaseController.prepend(Spree::BaseControllerDecorator)
