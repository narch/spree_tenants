module SpreeTenants
  module StockItemDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance
        
        # Inherit store_id from stock_location or variant
        inherit_store_id_from :stock_location, :variant
      end
    end
  end
end

Spree::StockItem.prepend(SpreeTenants::StockItemDecorator) if defined?(Spree::StockItem)