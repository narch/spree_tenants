module SpreeTenants
  module StockLocationDecorator
    def self.prepended(base)
      base.class_eval do
        # Include cross-tenant validation helpers
        include SpreeTenants::CrossTenantValidation
        
        # Remove the original name uniqueness validation if it exists
        if _validators[:name].any? { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
          _validators[:name].reject! { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
        end
        
        # Add store-scoped name uniqueness
        validates_uniqueness_scoped_to_store :name, 
          scope: :deleted_at
        
        # Ensure stock items belong to same store
        validate_same_store_for :stock_items
      end
    end
  end
end

Spree::StockLocation.prepend(SpreeTenants::StockLocationDecorator)