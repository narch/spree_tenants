module Spree
  module Admin
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
        # Use the current_store helper that Spree Admin provides
        if defined?(current_store) && current_store
          ActsAsTenant.current_tenant = current_store
        elsif Spree::Store.default
          # Fallback to default store if no current store
          ActsAsTenant.current_tenant = Spree::Store.default
        end
      end
    end
  end
end

Spree::Admin::BaseController.prepend Spree::Admin::BaseControllerDecorator if defined?(Spree::Admin::BaseController)