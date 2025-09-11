module SpreeTenants
  module OptionValueVariantDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance
        
        # Inherit store_id from variant or option_value
        inherit_store_id_from :variant, :option_value
        
        # Also ensure option_value gets store_id when created through this association
        before_validation :ensure_option_value_store_id
        
        private
        
        def ensure_option_value_store_id
          if option_value && store_id && option_value.store_id.blank?
            option_value.store_id = store_id
          end
        end
      end
    end
  end
end

Spree::OptionValueVariant.prepend(SpreeTenants::OptionValueVariantDecorator) if defined?(Spree::OptionValueVariant)