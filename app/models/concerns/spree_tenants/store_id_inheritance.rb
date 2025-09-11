module SpreeTenants
  module StoreIdInheritance
    extend ActiveSupport::Concern
    
    class_methods do
      # Automatically inherit store_id from specified associations
      # Usage: inherit_store_id_from :product, :taxonomy
      def inherit_store_id_from(*associations)
        before_validation :inherit_store_id
        
        define_method :inherit_store_id do
          return if store_id.present?
          
          associations.each do |association|
            if respond_to?(association)
              associated_record = send(association)
              if associated_record && associated_record.respond_to?(:store_id) && associated_record.store_id.present?
                self.store_id = associated_record.store_id
                break
              end
            end
          end
        end
        
        private :inherit_store_id
      end
    end
  end
end