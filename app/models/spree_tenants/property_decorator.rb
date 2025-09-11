module SpreeTenants
  module PropertyDecorator
    def self.prepended(base)
      base.class_eval do
        # Remove the original name uniqueness validation if it exists
        if _validators[:name].any? { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
          _validators[:name].reject! { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
        end
        
        # Add store-scoped name uniqueness
        validates :name, uniqueness: { 
          scope: :store_id,
          case_sensitive: false
        }
      end
    end
  end
end

Spree::Property.prepend(SpreeTenants::PropertyDecorator)