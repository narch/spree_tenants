module SpreeTenants
  module OrderDecorator
    def self.prepended(base)
      base.class_eval do
        # Order numbers remain globally unique (not per-store)
        # This is intentional - order numbers should be unique across all stores
        # for customer service, refunds, and tracking purposes
        
        # Override spree_base_uniqueness_scope to include store_id for other validations
        def self.spree_base_uniqueness_scope
          [:store_id]
        end
      end
    end
  end
end

Spree::Order.prepend(SpreeTenants::OrderDecorator)
