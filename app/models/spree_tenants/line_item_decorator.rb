module SpreeTenants
  module LineItemDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance
        
        # Inherit store_id from order or variant
        inherit_store_id_from :order, :variant
      end
    end
  end
end

Spree::LineItem.prepend(SpreeTenants::LineItemDecorator) if defined?(Spree::LineItem)
