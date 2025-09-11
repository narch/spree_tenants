module SpreeTenants
  module ClassificationDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance
        
        # Inherit store_id from product or taxon
        inherit_store_id_from :product, :taxon
      end
    end
  end
end

Spree::Classification.prepend(SpreeTenants::ClassificationDecorator) if defined?(Spree::Classification)