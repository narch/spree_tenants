require 'spec_helper'

RSpec.describe 'Acts as Tenant Integration' do
  # Create a test model with acts_as_tenant
  with_model :TestProduct do
    table do |t|
      t.integer :store_id
      t.string :name
      t.timestamps
    end

    model do
      acts_as_tenant :store, foreign_key: 'store_id', class_name: 'Spree::Store'
    end
  end

  let(:store) { create(:store) }
  let(:another_store) { create(:store) }
  
  describe 'tenant scoping' do
    let!(:store_product) { TestProduct.create!(name: 'Store Product', store_id: store.id) }
    let!(:another_store_product) { TestProduct.create!(name: 'Another Store Product', store_id: another_store.id) }

    it 'scopes queries to current tenant' do
      ActsAsTenant.with_tenant(store) do
        products = TestProduct.all
        expect(products).to include(store_product)
        expect(products).not_to include(another_store_product)
      end
    end

    it 'returns all records when no tenant is set' do
      ActsAsTenant.without_tenant do
        products = TestProduct.all
        expect(products).to include(store_product, another_store_product)
      end
    end

    it 'automatically sets store_id for new records' do
      ActsAsTenant.with_tenant(store) do
        product = TestProduct.create!(name: 'New Product')
        expect(product.store_id).to eq(store.id)
      end
    end

    it 'prevents access to other tenant records' do
      ActsAsTenant.with_tenant(store) do
        expect { TestProduct.find(another_store_product.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it 'allows switching tenants' do
      ActsAsTenant.with_tenant(store) do
        expect(TestProduct.count).to eq(1)
        expect(TestProduct.first).to eq(store_product)
      end

      ActsAsTenant.with_tenant(another_store) do
        expect(TestProduct.count).to eq(1)
        expect(TestProduct.first).to eq(another_store_product)
      end
    end
  end

  describe 'thread safety' do
    it 'isolates tenant per thread' do
      ActsAsTenant.current_tenant = store
      
      thread_tenant = nil
      thread = Thread.new do
        ActsAsTenant.current_tenant = another_store
        thread_tenant = ActsAsTenant.current_tenant
      end
      thread.join
      
      expect(thread_tenant).to eq(another_store)
      expect(ActsAsTenant.current_tenant).to eq(store)
    end
  end

  describe 'validation' do
    it 'requires store_id when tenant is not set' do
      ActsAsTenant.without_tenant do
        product = TestProduct.new(name: 'No Store Product')
        expect(product).not_to be_valid
        expect(product.errors[:store]).to include("must exist")
      end
    end

    it 'validates store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        product = TestProduct.new(name: 'Valid Product')
        expect(product).to be_valid
      end
    end
  end

  describe 'unscoped access' do
    let!(:store_product) { TestProduct.create!(name: 'Store Product', store_id: store.id) }
    let!(:another_store_product) { TestProduct.create!(name: 'Another Store Product', store_id: another_store.id) }

    it 'allows unscoped access when needed' do
      ActsAsTenant.with_tenant(store) do
        # Normal scoped access
        expect(TestProduct.count).to eq(1)
        
        # Unscoped access
        expect(TestProduct.unscoped.count).to eq(2)
        expect(TestProduct.unscoped).to include(store_product, another_store_product)
      end
    end
  end
end