module SpreeTenants
  module TaxCategoryDecorator
    def self.prepended(base)
      base.class_eval do
        # Include cross-tenant validation helpers
        include SpreeTenants::CrossTenantValidation
        
        # Remove the original name uniqueness validation
        _validators[:name].reject! { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
        
        # Add store-scoped name uniqueness
        validates_uniqueness_scoped_to_store :name, 
          scope: :deleted_at,
          case_sensitive: false
      end
    end
  end
end

Spree::TaxCategory.prepend(SpreeTenants::TaxCategoryDecorator)