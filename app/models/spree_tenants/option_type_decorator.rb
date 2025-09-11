module SpreeTenants
  module OptionTypeDecorator
    def self.prepended(base)
      base.class_eval do
        # Include cross-tenant validation helpers
        include SpreeTenants::CrossTenantValidation
        
        # Remove and replace name uniqueness validation
        validates_uniqueness_scoped_to_store :name
        
        # Ensure option values get store_id when created
        before_validation :ensure_option_values_store_id
        
        # Ensure option values belong to same store
        validate :option_values_belong_to_same_store
        
        private
        
        def ensure_option_values_store_id
          return unless store_id.present?
          
          option_values.each do |option_value|
            if option_value.store_id.blank?
              option_value.store_id = store_id
            end
          end
        end
        
        def option_values_belong_to_same_store
          return unless store_id.present?
          
          invalid_option_values = option_values.select { |ov| ov.store_id.present? && ov.store_id != store_id }
          if invalid_option_values.any?
            errors.add(:option_values, "must belong to the same store as the option type")
          end
        end
      end
    end
  end
end

Spree::OptionType.prepend(SpreeTenants::OptionTypeDecorator)