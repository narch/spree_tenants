module SpreeTenants
  module OptionValueDecorator
    def self.prepended(base)
      base.class_eval do
        # Include helpers
        include SpreeTenants::CrossTenantValidation
        include SpreeTenants::StoreIdInheritance
        
        # Inherit store_id from option type
        inherit_store_id_from :option_type
        
        # Remove and replace name uniqueness validation
        validates_uniqueness_scoped_to_store :name, scope: :option_type_id
        
        # Ensure option type belongs to same store
        validate :option_type_belongs_to_same_store
        
        private
        
        def option_type_belongs_to_same_store
          return unless store_id.present? && option_type.present?
          
          if option_type.store_id != store_id
            errors.add(:option_type, "must belong to the same store as the option value")
          end
        end
      end
    end
  end
end

Spree::OptionValue.prepend(SpreeTenants::OptionValueDecorator)