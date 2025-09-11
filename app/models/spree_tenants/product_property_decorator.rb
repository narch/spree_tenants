module SpreeTenants
  module ProductPropertyDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance
        
        # Inherit store_id from product or property
        inherit_store_id_from :product, :property
      end
    end
  end
end

Spree::ProductProperty.prepend(SpreeTenants::ProductPropertyDecorator) if defined?(Spree::ProductProperty)