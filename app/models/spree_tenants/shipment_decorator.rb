module SpreeTenants
  module ShipmentDecorator
    def self.prepended(base)
      base.class_eval do
        # Shipment numbers should be globally unique (not per-store)
        # This is intentional - shipment numbers should be unique across all stores
        # for tracking, customer service, and logistics purposes
        
        # Override spree_base_uniqueness_scope to include store_id for other validations
        def self.spree_base_uniqueness_scope
          [:store_id]
        end
      end
    end
  end
end

Spree::Shipment.prepend(SpreeTenants::ShipmentDecorator)
