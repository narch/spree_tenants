module SpreeTenants
  module VariantDecorator
    def self.prepended(base)
      base.class_eval do
        # Ensure variant inherits store_id from product
        # This is needed because master variant might be created before acts_as_tenant sets it
        before_validation :inherit_store_from_product
        
        # Validate option values belong to same store
        # Even with acts_as_tenant, we can still have invalid associations in tests or edge cases
        validate :option_values_belong_to_same_store
        
        private
        
        def inherit_store_from_product
          if store_id.blank? && product&.store_id.present?
            self.store_id = product.store_id
          end
        end
        
        def option_values_belong_to_same_store
          return unless store_id.present?
          
          invalid_option_values = option_values.select { |ov| ov.store_id.present? && ov.store_id != store_id }
          if invalid_option_values.any?
            errors.add(:option_values, "must belong to the same store as the variant")
          end
        end
      end
    end
  end
end

Spree::Variant.prepend(SpreeTenants::VariantDecorator)