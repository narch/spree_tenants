module SpreeTenants
  # Staff never see other stores in the admin.
  module AdminStoresHelperDecorator
    def self.apply!
      Spree::Admin::StoresHelper.module_eval do
        def available_stores
          @available_stores ||= Spree::Store.where(id: current_store&.id)
                                            .includes(:logo_attachment, :favicon_image_attachment, :default_custom_domain)
        end
      end
    end
  end
end

SpreeTenants::AdminStoresHelperDecorator.apply! if defined?(Spree::Admin::StoresHelper)
