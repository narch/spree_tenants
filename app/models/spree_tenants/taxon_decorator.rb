module SpreeTenants
  module TaxonDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance
        
        # Inherit store_id from taxonomy or parent
        inherit_store_id_from :taxonomy, :parent
      end
    end
  end
end

Spree::Taxon.prepend(SpreeTenants::TaxonDecorator) if defined?(Spree::Taxon)
