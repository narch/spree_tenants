require 'spec_helper'

RSpec.describe Spree::Store, type: :model do
  let(:store) { create(:store) }
  let(:another_store) { create(:store) }
  
  describe 'basic validation' do
    it 'creates a valid store' do
      expect(store).to be_valid
      expect(store).to be_persisted
      expect(store.id).to be_present
      expect(store.name).to eq('Store 1')
      expect(store.code).to eq('store1')
    end

    it 'creates another valid store' do
      expect(another_store).to be_valid
      expect(another_store).to be_persisted
      expect(another_store.id).to be_present
      expect(another_store.name).to eq('Store 2')
      expect(another_store.code).to eq('store2')
    end

    it 'stores are different' do
      expect(store.id).not_to eq(another_store.id)
      expect(store.code).not_to eq(another_store.code)
    end
  end

  describe 'tenant behavior' do
    it 'sets current tenant' do
      ActsAsTenant.with_tenant(store) do
        expect(ActsAsTenant.current_tenant).to eq(store)
        expect(ActsAsTenant.current_tenant.id).to eq(store.id)
      end
    end

    it 'switches tenants correctly' do
      ActsAsTenant.with_tenant(store) do
        expect(ActsAsTenant.current_tenant).to eq(store)
      end

      ActsAsTenant.with_tenant(another_store) do
        expect(ActsAsTenant.current_tenant).to eq(another_store)
      end

      expect(ActsAsTenant.current_tenant).to be_nil
    end
  end
  
  describe 'associations' do
    it 'has many products' do
      association = Spree::Store.reflect_on_association(:products)
      expect(association).to be_present
      expect(association.macro).to eq(:has_many)
      expect(association.options[:foreign_key]).to eq(:store_id)
    end
    
    it 'has many orders' do
      association = Spree::Store.reflect_on_association(:orders)
      expect(association).to be_present
      expect(association.macro).to eq(:has_many)
      expect(association.options[:foreign_key]).to eq(:store_id)
    end
    
    it 'has many taxonomies' do
      association = Spree::Store.reflect_on_association(:taxonomies)
      expect(association).to be_present
      expect(association.macro).to eq(:has_many)
      expect(association.options[:foreign_key]).to eq(:store_id)
    end
    
    it 'has many variants through products' do
      association = Spree::Store.reflect_on_association(:variants)
      expect(association).to be_present
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:products)
    end
  end
  
  describe '#with_tenant' do
    it 'executes block with store as tenant' do
      product = nil
      
      store.with_tenant do
        product = create(:product, store_id: store.id)
        expect(ActsAsTenant.current_tenant).to eq(store)
      end
      
      expect(product.store_id).to eq(store.id)
    end
    
    it 'isolates data between stores' do
      product1 = nil
      product2 = nil
      
      store.with_tenant do
        product1 = create(:product, store_id: store.id)
      end
      
      another_store.with_tenant do
        product2 = create(:product, store_id: another_store.id)
        products = Spree::Product.all
        expect(products).to include(product2)
        expect(products).not_to include(product1)
      end
    end
  end
  
  describe '#all_products' do
    before do
      ActsAsTenant.with_tenant(store) do
        create(:product, store_id: store.id)
      end
      ActsAsTenant.with_tenant(another_store) do
        create(:product, store_id: another_store.id)
      end
    end
    
    it 'returns products for this store only, bypassing current tenant' do
      ActsAsTenant.with_tenant(another_store) do
        products = store.all_products
        expect(products.count).to eq(1)
        expect(products.first.store_id).to eq(store.id)
      end
    end
  end
  
  describe '#all_orders' do
    before do
      ActsAsTenant.with_tenant(store) do
        create(:order, store_id: store.id)
      end
      ActsAsTenant.with_tenant(another_store) do
        create(:order, store_id: another_store.id)
      end
    end
    
    it 'returns orders for this store only, bypassing current tenant' do
      ActsAsTenant.with_tenant(another_store) do
        orders = store.all_orders
        expect(orders.count).to eq(1)
        expect(orders.first.store_id).to eq(store.id)
      end
    end
  end
  
  describe 'dependent associations' do
    it 'restricts deletion when products exist' do
      ActsAsTenant.with_tenant(store) do
        create(:product, store_id: store.id)
      end
      
      expect { store.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
    
    it 'restricts deletion when orders exist' do
      ActsAsTenant.with_tenant(store) do
        create(:order, store_id: store.id)
      end
      
      expect { store.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end
end