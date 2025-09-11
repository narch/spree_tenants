module SpreeTenants
  module PaymentMethodDecorator
    def self.prepended(base)
      base.class_eval do
        # Override the for_store scope to use direct store_id
        scope :for_store, ->(store) { unscoped.where(store_id: store.id) }
        
        # PaymentMethod already has available_for_store? method
        # We need to override it to use store_id instead of the join table
        def available_for_store?(store)
          return true if store.blank?
          self.store_id == store.id
        end
        
        # Override the stores association to return an array with just the payment method's store
        def stores
          store ? [store] : []
        end
        
        # Override store_ids to work with single store
        def store_ids
          store_id ? [store_id] : []
        end
        
        def store_ids=(ids)
          self.store_id = ids.first if ids.present?
        end
        
        # Disable MultiStoreResource validations since we're using acts_as_tenant
        def disable_store_presence_validation?
          true
        end
      end
    end
  end
end

Spree::PaymentMethod.prepend(SpreeTenants::PaymentMethodDecorator)
