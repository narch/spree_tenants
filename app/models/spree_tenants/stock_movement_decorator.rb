module SpreeTenants
  module StockMovementDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance
        
        # Inherit store_id from stock_item
        inherit_store_id_from :stock_item
      end
    end
  end
end

Spree::StockMovement.prepend(SpreeTenants::StockMovementDecorator) if defined?(Spree::StockMovement)