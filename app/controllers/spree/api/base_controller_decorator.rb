module Spree
  module Api
    module BaseControllerDecorator
      def self.prepended(base)
        base.class_eval do
          # Set current tenant through filter
          set_current_tenant_through_filter
          
          # Set the tenant before any action
          before_action :set_current_tenant
        end
      end
      
      private
      
      def set_current_tenant
        # For API, we need to determine the store from the request
        # This could be from a header, subdomain, or token
        store = find_store_from_request
        
        if store
          ActsAsTenant.current_tenant = store
        elsif Spree::Store.default
          # Fallback to default store
          ActsAsTenant.current_tenant = Spree::Store.default
        end
      end
      
      def find_store_from_request
        # Check for store in various places
        # 1. X-Spree-Store header
        if request.headers['X-Spree-Store'].present?
          Spree::Store.find_by(code: request.headers['X-Spree-Store'])
        # 2. Store parameter
        elsif params[:store_id].present?
          Spree::Store.find_by(id: params[:store_id])
        # 3. Subdomain
        elsif request.subdomain.present?
          Spree::Store.find_by(code: request.subdomain)
        # 4. Current store helper if available
        elsif defined?(current_store) && current_store
          current_store
        end
      end
    end
  end
end

Spree::Api::BaseController.prepend Spree::Api::BaseControllerDecorator if defined?(Spree::Api::BaseController)