require 'spec_helper'

RSpec.describe Spree::Role, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        role = Spree::Role.new(name: 'admin')
        
        expect(role.store_id).to eq(store.id)
      end
    end

    it 'creates roles within tenant context' do
      ActsAsTenant.with_tenant(store) do
        role = Spree::Role.create!(name: 'admin')
        
        expect(role.store_id).to eq(store.id)
      end
    end

    it 'allows same role name across different stores' do
      ActsAsTenant.with_tenant(store) do
        role1 = Spree::Role.create!(name: 'admin')
        expect(role1.store_id).to eq(store.id)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        role2 = Spree::Role.create!(name: 'admin')
        expect(role2.store_id).to eq(another_store.id)
      end
    end

    it 'prevents duplicate role name within same store' do
      ActsAsTenant.with_tenant(store) do
        Spree::Role.create!(name: 'admin')
        
        expect {
          Spree::Role.create!(name: 'admin')
        }.to raise_error(ActiveRecord::RecordInvalid, /Name has already been taken/)
      end
    end
  end
end
