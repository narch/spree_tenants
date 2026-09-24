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
      
      # Each store also has the zone provisioned for its default country.
      ActsAsTenant.with_tenant(store) do
        expect(Spree::Zone.pluck(:name)).to include('North America')
        expect(Spree::Zone.pluck(:name)).not_to include('Europe')
        expect(Spree::Zone.pluck(:store_id).uniq).to eq([store.id])
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::Zone.pluck(:name)).to include('Europe')
        expect(Spree::Zone.pluck(:name)).not_to include('North America')
        expect(Spree::Zone.pluck(:store_id).uniq).to eq([another_store.id])
      end
    end
  end
end
