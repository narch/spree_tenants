module SpreeTenants
  module RoleDecorator
    def self.prepended(base)
      base.class_eval do
        # Remove the existing uniqueness validation from Spree::UniqueName
        _validators.delete(:name)
        _validate_callbacks.each do |callback|
          if callback.filter.is_a?(ActiveRecord::Validations::UniquenessValidator) &&
             callback.filter.attributes.include?(:name)
            skip_callback(:validate, callback.kind, callback.filter)
          end
        end
        
        # Add store-scoped uniqueness validation
        validates :name, uniqueness: { scope: :store_id, case_sensitive: false }
        
        # Override spree_base_uniqueness_scope to include store_id for other validations
        def self.spree_base_uniqueness_scope
          [:store_id]
        end
      end
    end
  end
end

Spree::Role.prepend(SpreeTenants::RoleDecorator) if defined?(Spree::Role)
