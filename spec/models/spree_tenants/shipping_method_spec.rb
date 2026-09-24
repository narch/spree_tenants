require 'spec_helper'

RSpec.describe Spree::ShippingMethod, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        shipping_method = Spree::ShippingMethod.new(
          name: 'Standard Shipping',
          display_on: 'both',
          calculator: Spree::Calculator::Shipping::FlatRate.new
        )
        
        expect(shipping_method.store_id).to eq(store.id)
      end
    end

    it 'creates shipping methods within tenant context' do
      ActsAsTenant.with_tenant(store) do
        shipping_category = create(:shipping_category)
        shipping_method = Spree::ShippingMethod.create!(
          name: 'Standard Shipping',
          display_on: 'both',
          calculator: Spree::Calculator::Shipping::FlatRate.new,
          shipping_categories: [shipping_category]
        )
        
        expect(shipping_method.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      ActsAsTenant.with_tenant(store) do
        shipping_category = create(:shipping_category)
        shipping_method = Spree::ShippingMethod.create!(
          name: 'Standard Shipping',
          display_on: 'both',
          calculator: Spree::Calculator::Shipping::FlatRate.new,
          shipping_categories: [shipping_category]
        )
      end
      
      ActsAsTenant.with_tenant(another_store) do
        shipping_category2 = create(:shipping_category)
        shipping_method2 = Spree::ShippingMethod.create!(
          name: 'Express Shipping',
          display_on: 'both',
          calculator: Spree::Calculator::Shipping::FlatRate.new,
          shipping_categories: [shipping_category2]
        )
      end
      
      # Each store also has its provisioned Digital Delivery method.
      ActsAsTenant.with_tenant(store) do
        expect(Spree::ShippingMethod.pluck(:name)).to include('Standard Shipping')
        expect(Spree::ShippingMethod.pluck(:name)).not_to include('Express Shipping')
        expect(Spree::ShippingMethod.pluck(:store_id).uniq).to eq([store.id])
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::ShippingMethod.pluck(:name)).to include('Express Shipping')
        expect(Spree::ShippingMethod.pluck(:name)).not_to include('Standard Shipping')
        expect(Spree::ShippingMethod.pluck(:store_id).uniq).to eq([another_store.id])
      end
    end
  end
end
