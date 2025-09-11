require 'spec_helper'

RSpec.describe Spree::Taxon, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'store_id inheritance' do
    it 'inherits store_id from taxonomy when creating taxon' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = create(:taxonomy, name: 'Test Categories')
        root = taxonomy.root
        
        taxon = Spree::Taxon.create!(
          name: 'Electronics',
          taxonomy: taxonomy,
          parent: root
        )
        
        expect(taxon.store_id).to eq(store.id)
        expect(taxon.taxonomy.store_id).to eq(store.id)
      end
    end

    it 'inherits store_id from parent when creating nested taxon' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = create(:taxonomy, name: 'Test Categories')
        root = taxonomy.root
        
        parent = Spree::Taxon.create!(
          name: 'Electronics',
          taxonomy: taxonomy,
          parent: root
        )
        
        child = Spree::Taxon.create!(
          name: 'Phones',
          taxonomy: taxonomy,
          parent: parent
        )
        
        expect(child.store_id).to eq(store.id)
        expect(parent.store_id).to eq(store.id)
      end
    end

    it 'handles store_id inheritance without tenant context' do
      # Test that our concern works even without acts_as_tenant context
      taxonomy = create(:taxonomy, name: 'Test Categories', store: store)
      root = taxonomy.root
      
      taxon = Spree::Taxon.create!(
        name: 'Electronics',
        taxonomy: taxonomy,
        parent: root
      )
      
      expect(taxon.store_id).to eq(store.id)
    end
  end
end