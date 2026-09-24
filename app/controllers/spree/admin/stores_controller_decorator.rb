module Spree
  module Admin
    # Spree copies staff into a new store and redirects there. Staff are per
    # store, so give the creator their own admin account in the new store.
    module StoresControllerDecorator
      def create
        super

        return unless @store&.persisted?

        creator = try_spree_current_user
        return unless creator.is_a?(Spree.admin_user_class)

        SpreeTenants::StoreProvisioner.bootstrap_admin_from!(@store, creator)
      end
    end
  end
end

Spree::Admin::StoresController.prepend(Spree::Admin::StoresControllerDecorator) if defined?(Spree::Admin::StoresController)
