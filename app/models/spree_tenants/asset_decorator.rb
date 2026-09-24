module SpreeTenants
  # Images and other assets take their store from what they are attached to.
  module AssetDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        inherit_store_id_from :viewable
      end
    end
  end
end

Spree::Asset.prepend(SpreeTenants::AssetDecorator) if defined?(Spree::Asset)
