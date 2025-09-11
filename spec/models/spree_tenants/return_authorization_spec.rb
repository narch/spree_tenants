require 'spec_helper'

RSpec.describe Spree::ReturnAuthorization, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        reason = create(:return_authorization_reason)
        return_authorization = Spree::ReturnAuthorization.new(
          order: order,
          reason: reason
        )
        
        expect(return_authorization.store_id).to eq(store.id)
      end
    end

    it 'creates return authorizations within tenant context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        reason = create(:return_authorization_reason)
        stock_location = create(:stock_location)
        
        # Create a simple return authorization without complex order requirements
        return_authorization = Spree::ReturnAuthorization.new(
          order: order,
          reason: reason,
          stock_location: stock_location
        )
        
        # Skip validations that require shipped units for this test
        return_authorization.save!(validate: false)
        
        expect(return_authorization.store_id).to eq(store.id)
        expect(return_authorization.order.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        reason = create(:return_authorization_reason)
        stock_location = create(:stock_location)
        
        return_authorization = Spree::ReturnAuthorization.new(
          order: order,
          reason: reason,
          stock_location: stock_location
        )
        return_authorization.save!(validate: false)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        order2 = create(:order)
        reason2 = create(:return_authorization_reason)
        stock_location2 = create(:stock_location)
        
        return_authorization2 = Spree::ReturnAuthorization.new(
          order: order2,
          reason: reason2,
          stock_location: stock_location2
        )
        return_authorization2.save!(validate: false)
      end
      
      ActsAsTenant.with_tenant(store) do
        expect(Spree::ReturnAuthorization.count).to eq(1)
        expect(Spree::ReturnAuthorization.first.order.store_id).to eq(store.id)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::ReturnAuthorization.count).to eq(1)
        expect(Spree::ReturnAuthorization.first.order.store_id).to eq(another_store.id)
      end
    end
  end
end
