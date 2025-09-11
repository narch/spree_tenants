require 'spec_helper'

RSpec.describe Spree::Zone, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        zone = Spree::Zone.new(
          name: 'North America',
          description: 'North American zone'
        )
        
        expect(zone.store_id).to eq(store.id)
      end
    end

    it 'creates zones within tenant context' do
      ActsAsTenant.with_tenant(store) do
        zone = Spree::Zone.create!(
          name: 'North America',
          description: 'North American zone'
        )
        
        expect(zone.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      ActsAsTenant.with_tenant(store) do
        zone = Spree::Zone.create!(
          name: 'North America',
          description: 'North American zone'
        )
      end
      
      ActsAsTenant.with_tenant(another_store) do
        zone2 = Spree::Zone.create!(
          name: 'Europe',
          description: 'European zone'
        )
      end
      
      ActsAsTenant.with_tenant(store) do
        expect(Spree::Zone.count).to eq(1)
        expect(Spree::Zone.first.name).to eq('North America')
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::Zone.count).to eq(1)
        expect(Spree::Zone.first.name).to eq('Europe')
      end
    end
  end
end
