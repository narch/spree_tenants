require 'spec_helper'

RSpec.describe Spree::PaymentMethod, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        payment_method = Spree::PaymentMethod.new(
          name: 'Credit Card',
          type: 'Spree::PaymentMethod::Check'
        )
        
        expect(payment_method.store_id).to eq(store.id)
      end
    end

    it 'creates payment methods within tenant context' do
      ActsAsTenant.with_tenant(store) do
        payment_method = Spree::PaymentMethod.create!(
          name: 'Credit Card',
          type: 'Spree::PaymentMethod::Check'
        )
        
        expect(payment_method.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      ActsAsTenant.with_tenant(store) do
        payment_method = Spree::PaymentMethod.create!(
          name: 'Credit Card',
          type: 'Spree::PaymentMethod::Check'
        )
      end
      
      ActsAsTenant.with_tenant(another_store) do
        payment_method2 = Spree::PaymentMethod.create!(
          name: 'PayPal',
          type: 'Spree::PaymentMethod::Check'
        )
      end
      
      ActsAsTenant.with_tenant(store) do
        expect(Spree::PaymentMethod.count).to eq(1)
        expect(Spree::PaymentMethod.first.name).to eq('Credit Card')
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::PaymentMethod.count).to eq(1)
        expect(Spree::PaymentMethod.first.name).to eq('PayPal')
      end
    end
  end
end
