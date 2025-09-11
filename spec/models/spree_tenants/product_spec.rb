require 'spec_helper'

RSpec.describe Spree::Product, type: :model do
  include_context 'multi_tenant_setup'
  
  before do
    # Ensure default records exist for both stores
    ensure_default_records_for_store(store)
    ensure_default_records_for_store(another_store)
  end
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        product = Spree::Product.new(
          name: 'Test Product',
          slug: 'test-product',
          price: 10.00
        )
        
        expect(product.store_id).to eq(store.id)
      end
    end

    it 'creates a product within tenant context' do
      ActsAsTenant.with_tenant(store) do
        product = Spree::Product.create!(
          name: 'Test Product',
          slug: 'test-product',
          price: 10.00
        )
        
        expect(product).to be_persisted
        expect(product.store_id).to eq(store.id)
        expect(product.master.store_id).to eq(store.id)
      end
    end

    it 'allows products with same slug in different stores' do
      product1 = ActsAsTenant.with_tenant(store) do
        Spree::Product.create!(
          name: 'Test Product',
          slug: 'test-product',
          price: 10.00
        )
      end

      product2 = ActsAsTenant.with_tenant(another_store) do
        Spree::Product.create!(
          name: 'Test Product',
          slug: 'test-product',
          price: 10.00
        )
      end

      expect(product1.store_id).to eq(store.id)
      expect(product2.store_id).to eq(another_store.id)
      expect(product1.slug).to eq(product2.slug)
    end

    it 'scopes queries to current tenant' do
      product1 = ActsAsTenant.with_tenant(store) do
        Spree::Product.create!(
          name: 'Store 1 Product',
          slug: 'store1-product',
          price: 10.00
        )
      end

      product2 = ActsAsTenant.with_tenant(another_store) do
        Spree::Product.create!(
          name: 'Store 2 Product',
          slug: 'store2-product',
          price: 20.00
        )
      end

      ActsAsTenant.with_tenant(store) do
        products = Spree::Product.all
        expect(products).to include(product1)
        expect(products).not_to include(product2)
      end

      ActsAsTenant.with_tenant(another_store) do
        products = Spree::Product.all
        expect(products).to include(product2)
        expect(products).not_to include(product1)
      end
    end
  end
  
  describe 'slug uniqueness validation' do
    it 'allows same slug in different stores' do
      ActsAsTenant.with_tenant(store) do
        create(:product, slug: 'awesome-product')
      end
      
      ActsAsTenant.with_tenant(another_store) do
        product = build(:product, slug: 'awesome-product')
        expect(product).to be_valid
      end
    end
    
    it 'prevents duplicate slugs within same store' do
      ActsAsTenant.with_tenant(store) do
        create(:product, slug: 'awesome-product')
        duplicate = build(:product, slug: 'awesome-product', store_id: store.id)
        
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:slug]).to include('has already been taken')
      end
    end
    
    it 'is case insensitive' do
      ActsAsTenant.with_tenant(store) do
        create(:product, slug: 'awesome-product')
        duplicate = build(:product, slug: 'AWESOME-PRODUCT', store_id: store.id)
        
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:slug]).to include('has already been taken')
      end
    end
    
    it 'ignores deleted products' do
      ActsAsTenant.with_tenant(store) do
        deleted_product = create(:product, slug: 'awesome-product')
        deleted_product.destroy
        
        new_product = build(:product, slug: 'awesome-product', store_id: store.id)
        expect(new_product).to be_valid
      end
    end
  end
  
  describe 'cross-tenant validations' do
    describe '#taxons_belong_to_same_store' do
      let(:product) { create(:product, store_id: store.id) }
      let(:store_taxonomy) { create(:taxonomy, store_id: store.id) }
      let(:store_taxon) { create(:taxon, taxonomy: store_taxonomy, store_id: store.id) }
      let(:another_store_taxonomy) { create(:taxonomy, store_id: another_store.id) }
      let(:another_store_taxon) { create(:taxon, taxonomy: another_store_taxonomy, store_id: another_store.id) }
      
      it 'allows taxons from same store' do
        ActsAsTenant.without_tenant do
          product.taxons << store_taxon
          expect(product).to be_valid
        end
      end
      
      it 'prevents taxons from different stores' do
        ActsAsTenant.without_tenant do
          product.taxons << another_store_taxon
          expect(product).not_to be_valid
          expect(product.errors[:taxons]).to include('must belong to the same store as the product')
        end
      end
    end
    
    describe '#properties_belong_to_same_store' do
      let(:product) { create(:product, store_id: store.id) }
      let(:store_property) { create(:property, store_id: store.id) }
      let(:another_store_property) { create(:property, store_id: another_store.id) }
      
      it 'allows properties from same store' do
        ActsAsTenant.without_tenant do
          product.product_properties.create(property: store_property, value: 'test')
          expect(product).to be_valid
        end
      end
      
      it 'prevents properties from different stores' do
        ActsAsTenant.without_tenant do
          product.product_properties.create(property: another_store_property, value: 'test')
          expect(product).not_to be_valid
          expect(product.errors[:properties]).to include('must belong to the same store as the product')
        end
      end
    end
  end
  
  describe 'slug generation' do
    it 'generates slug when blank' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product, name: 'Amazing Product', slug: nil)
        expect(product.slug).to eq('amazing-product')
      end
    end
    
    it 'regenerates slug when changed' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product, slug: 'old-slug')
        product.update(slug: 'new-slug')
        expect(product.slug).to eq('new-slug')
      end
    end
  end
end