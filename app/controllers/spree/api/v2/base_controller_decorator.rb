module Spree
  module Api
    module V2
      # API v2 controllers inherit from ActionController::API, not Spree::BaseController.
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
  end
end

if defined?(Spree::Api::V2::BaseController)
  Spree::Api::V2::BaseController.prepend(Spree::Api::V2::BaseControllerDecorator)
end
