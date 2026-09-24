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

    it 'is provisioned with the standard roles when the store is created' do
      ActsAsTenant.with_tenant(store) do
        expect(Spree::Role.pluck(:name)).to match_array(%w[admin user])
        expect(Spree::Role.default_admin_role.store_id).to eq(store.id)
      end
    end

    it 'creates roles within tenant context' do
      ActsAsTenant.with_tenant(store) do
        role = Spree::Role.create!(name: 'manager')
        
        expect(role.store_id).to eq(store.id)
      end
    end

    it 'allows same role name across different stores' do
      ActsAsTenant.with_tenant(store) do
        role1 = Spree::Role.create!(name: 'manager')
        expect(role1.store_id).to eq(store.id)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        role2 = Spree::Role.create!(name: 'manager')
        expect(role2.store_id).to eq(another_store.id)
      end
    end

    it 'prevents duplicate role name within same store' do
      ActsAsTenant.with_tenant(store) do
        Spree::Role.create!(name: 'manager')
        
        expect {
          Spree::Role.create!(name: 'manager')
        }.to raise_error(ActiveRecord::RecordInvalid, /Name has already been taken/)
      end
    end
  end
end
