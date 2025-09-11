module SpreeTenants
  module ShippingCategoryDecorator
    def self.prepended(base)
      base.class_eval do
        # Include cross-tenant validation helpers
        include SpreeTenants::CrossTenantValidation
        
        # Remove only the uniqueness validators for :name
        if _validators[:name]
          _validators[:name] = _validators[:name].reject { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
        end
        
        # Add store-scoped name uniqueness
        validates_uniqueness_scoped_to_store :name
      end
    end
  end
end

Spree::ShippingCategory.prepend(SpreeTenants::ShippingCategoryDecorator)