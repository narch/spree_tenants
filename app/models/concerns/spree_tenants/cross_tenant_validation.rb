module SpreeTenants
  module CrossTenantValidation
    extend ActiveSupport::Concern
    
    class_methods do
      # Add validation to ensure associated records belong to same store
      def validate_same_store_for(*associations)
        associations.each do |association|
          validate "#{association}_belong_to_same_store".to_sym
          
          define_method "#{association}_belong_to_same_store" do
            return unless store_id.present?
            
            assoc_records = send(association)
            return unless assoc_records
            
            # Handle both single records and collections
            records = assoc_records.respond_to?(:each) ? assoc_records : [assoc_records]
            
            records.each do |record|
              next unless record && record.respond_to?(:store_id)
              
              if record.store_id != store_id
                errors.add(association, "must belong to the same store")
                break
              end
            end
          end
        end
      end
      
      # Add store-scoped uniqueness validation
      def validates_uniqueness_scoped_to_store(attribute, options = {})
        # Remove any existing uniqueness validators for this attribute
        if _validators[attribute]
          _validators[attribute] = _validators[attribute].reject { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
        end
        
        # Remove validation callbacks for uniqueness validators on this attribute
        _validate_callbacks.each do |callback|
          if callback.filter.is_a?(ActiveRecord::Validations::UniquenessValidator)
            if callback.filter.respond_to?(:attributes) && callback.filter.attributes.include?(attribute)
              skip_callback(:validate, callback.kind, callback.filter)
            end
          end
        end
        
        # Default options
        default_options = {
          scope: :store_id,
          case_sensitive: false
        }
        
        # If additional scope is provided, combine with store_id
        if options[:scope]
          scopes = Array(options[:scope])
          scopes << :store_id unless scopes.include?(:store_id)
          options[:scope] = scopes
        else
          options[:scope] = :store_id
        end
        
        # Merge with defaults
        validation_options = default_options.merge(options)
        
        # Add the new validation
        validates attribute, uniqueness: validation_options
      end
    end
    
    included do
      # Helper method to check if a record belongs to the same store
      def same_store?(other_record)
        return true unless other_record.respond_to?(:store_id)
        store_id == other_record.store_id
      end
      
      # Helper method to get records from same store only
      def filter_by_same_store(collection)
        return collection unless store_id.present?
        collection.where(store_id: store_id)
      end
    end
  end
end