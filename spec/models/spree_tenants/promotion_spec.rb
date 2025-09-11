require 'spec_helper'

RSpec.describe Spree::Promotion, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        promotion = Spree::Promotion.new(
          name: '10% Off',
          description: '10% discount promotion',
          code: 'TENPERCENT'
        )
        
        expect(promotion.store_id).to eq(store.id)
      end
    end

    it 'creates promotions within tenant context' do
      ActsAsTenant.with_tenant(store) do
        promotion = Spree::Promotion.create!(
          name: '10% Off',
          description: '10% discount promotion',
          code: 'TENPERCENT'
        )
        
        expect(promotion.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      ActsAsTenant.with_tenant(store) do
        promotion = Spree::Promotion.create!(
          name: '10% Off',
          description: '10% discount promotion',
          code: 'TENPERCENT'
        )
      end
      
      ActsAsTenant.with_tenant(another_store) do
        promotion2 = Spree::Promotion.create!(
          name: 'Free Shipping',
          description: 'Free shipping promotion',
          code: 'FREESHIP'
        )
      end
      
      ActsAsTenant.with_tenant(store) do
        expect(Spree::Promotion.count).to eq(1)
        expect(Spree::Promotion.first.name).to eq('10% Off')
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::Promotion.count).to eq(1)
        expect(Spree::Promotion.first.name).to eq('Free Shipping')
      end
    end
  end
end
