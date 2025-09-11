module SpreeTenants
  module PaymentDecorator
    def self.prepended(base)
      base.class_eval do
        # Payment numbers should be globally unique (not per-store)
        # This is intentional - payment numbers should be unique across all stores
        # for payment processing, refunds, and tracking purposes
        
        # Override spree_base_uniqueness_scope to include store_id for other validations
        def self.spree_base_uniqueness_scope
          [:store_id]
        end
      end
    end
  end
end

Spree::Payment.prepend(SpreeTenants::PaymentDecorator)
