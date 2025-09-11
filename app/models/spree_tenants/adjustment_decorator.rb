module SpreeTenants
  module AdjustmentDecorator
    def self.prepended(base)
      base.class_eval do
        # Adjustments don't typically have unique constraints that need store scoping
        # but we'll add the uniqueness scope for consistency
        
        # Override spree_base_uniqueness_scope to include store_id for other validations
        def self.spree_base_uniqueness_scope
          [:store_id]
        end
      end
    end
  end
end

Spree::Adjustment.prepend(SpreeTenants::AdjustmentDecorator)
