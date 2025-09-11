require 'spec_helper'

RSpec.describe Spree::Taxonomy, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.new(
          name: 'Test Categories'
        )
        
        expect(taxonomy.store_id).to eq(store.id)
      end
    end

    it 'creates taxonomies within tenant context' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.create!(
          name: 'Test Categories',
          position: 1
        )
        
        expect(taxonomy).to be_persisted
        expect(taxonomy.store_id).to eq(store.id)
        expect(taxonomy.root).not_to be_nil
        expect(taxonomy.root.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      taxonomy1 = ActsAsTenant.with_tenant(store) do
        Spree::Taxonomy.create!(name: 'Store 1 Categories')
      end

      taxonomy2 = ActsAsTenant.with_tenant(another_store) do
        Spree::Taxonomy.create!(name: 'Store 2 Categories')
      end

      ActsAsTenant.with_tenant(store) do
        taxonomies = Spree::Taxonomy.all
        expect(taxonomies).to include(taxonomy1)
        expect(taxonomies).not_to include(taxonomy2)
      end

      ActsAsTenant.with_tenant(another_store) do
        taxonomies = Spree::Taxonomy.all
        expect(taxonomies).to include(taxonomy2)
        expect(taxonomies).not_to include(taxonomy1)
      end
    end

    it 'prevents cross-tenant taxonomy access' do
      taxonomy = ActsAsTenant.with_tenant(store) do
        Spree::Taxonomy.create!(name: 'Test Categories 2')
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::Taxonomy.find_by(id: taxonomy.id)).to be_nil
      end
    end

    it 'isolates taxon hierarchy per store' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.create!(name: 'Test Categories 3')
        root = taxonomy.root
        
        # Create child taxons
        clothing = root.children.create!(
          name: 'Clothing',
          taxonomy: taxonomy
        )
        
        shirts = clothing.children.create!(
          name: 'Shirts',
          taxonomy: taxonomy
        )
        
        expect(root.children.count).to eq(1)
        expect(clothing.children.count).to eq(1)
        expect(taxonomy.taxons.count).to eq(3) # root + clothing + shirts
        expect(taxonomy.taxons.pluck(:store_id).uniq).to eq([store.id])
      end
    end
  end

  describe 'taxon management' do
    it 'creates nested taxons within store' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.create!(name: 'Products')
        root = taxonomy.root
        
        # Create child taxon
        electronics = root.children.create!(
          name: 'Electronics',
          taxonomy: taxonomy,
          permalink: 'electronics'
        )
        
        # Check basic hierarchy
        expect(electronics.parent).to eq(root)
        expect(electronics.taxonomy).to eq(taxonomy)
        expect(electronics.store_id).to eq(store.id)
        expect(root.children).to include(electronics)
      end
    end

    it 'maintains separate category trees per store' do
      # Store 1 category tree
      store1_tree = ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.create!(name: 'Test Categories')
        root = taxonomy.root
        
        food = root.children.create!(
          name: 'Food',
          taxonomy: taxonomy
        )
        
        food.children.create!(
          name: 'Fruits',
          taxonomy: taxonomy
        )
        
        taxonomy
      end
      
      # Store 2 category tree
      store2_tree = ActsAsTenant.with_tenant(another_store) do
        taxonomy = Spree::Taxonomy.create!(name: 'Test Categories')
        root = taxonomy.root
        
        books = root.children.create!(
          name: 'Books',
          taxonomy: taxonomy
        )
        
        books.children.create!(
          name: 'Fiction',
          taxonomy: taxonomy
        )
        
        taxonomy
      end
      
      ActsAsTenant.with_tenant(store) do
        taxons = Spree::Taxon.all
        expect(taxons.pluck(:name)).to include('Categories', 'Food', 'Fruits')
        expect(taxons.pluck(:name)).not_to include('Books', 'Fiction')
      end
      
      ActsAsTenant.with_tenant(another_store) do
        taxons = Spree::Taxon.all
        expect(taxons.pluck(:name)).to include('Categories', 'Books', 'Fiction')
        expect(taxons.pluck(:name)).not_to include('Food', 'Fruits')
      end
    end

    it 'handles taxon positions within store' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.create!(name: 'Test Categories')
        root = taxonomy.root
        
        # Create taxons with positions
        taxon1 = root.children.create!(
          name: 'First',
          taxonomy: taxonomy,
          position: 1
        )
        
        taxon2 = root.children.create!(
          name: 'Second',
          taxonomy: taxonomy,
          position: 2
        )
        
        # Check basic positioning
        expect(taxon1.position).to eq(1)
        expect(taxon2.position).to eq(2)
        expect(taxon1.store_id).to eq(store.id)
        expect(taxon2.store_id).to eq(store.id)
      end
    end
  end

  describe 'product associations' do
    it 'associates products with taxons within store' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.create!(name: 'Test Categories')
        root = taxonomy.root
        
        category = root.children.create!(
          name: 'Electronics',
          taxonomy: taxonomy
        )
        
        product = create(:product, name: 'Laptop')
        
        # Create classification linking product to taxon
        classification = Spree::Classification.create!(
          product: product,
          taxon: category
        )
        
        expect(classification.store_id).to eq(store.id)
        expect(category.products).to include(product)
        expect(product.taxons).to include(category)
      end
    end

    it 'isolates product-taxon relationships by store' do
      product1 = ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.create!(name: 'Test Categories')
        category = taxonomy.root.children.create!(
          name: 'Clothing',
          taxonomy: taxonomy
        )
        
        product = create(:product, name: 'T-Shirt')
        product.taxons << category
        product
      end
      
      product2 = ActsAsTenant.with_tenant(another_store) do
        taxonomy = Spree::Taxonomy.create!(name: 'Test Categories')
        category = taxonomy.root.children.create!(
          name: 'Electronics',
          taxonomy: taxonomy
        )
        
        product = create(:product, name: 'Phone')
        product.taxons << category
        product
      end
      
      ActsAsTenant.with_tenant(store) do
        classifications = Spree::Classification.all
        expect(classifications.map(&:product_id)).to include(product1.id)
        expect(classifications.map(&:product_id)).not_to include(product2.id)
      end
    end
  end

  describe 'taxonomy operations' do
    it 'updates taxonomies within store context' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.create!(
          name: 'Old Name',
          position: 1
        )
        
        taxonomy.update!(name: 'New Name', position: 2)
        
        expect(taxonomy.name).to eq('New Name')
        expect(taxonomy.position).to eq(2)
        expect(taxonomy.store_id).to eq(store.id)
      end
    end

    it 'deletes taxonomies and their taxons' do
      ActsAsTenant.with_tenant(store) do
        taxonomy = Spree::Taxonomy.create!(name: 'To Delete')
        root = taxonomy.root
        
        child = root.children.create!(
          name: 'Child',
          taxonomy: taxonomy
        )
        
        grandchild = child.children.create!(
          name: 'Grandchild',
          taxonomy: taxonomy
        )
        
        taxonomy_id = taxonomy.id
        taxon_ids = [root.id, child.id, grandchild.id]
        
        taxonomy.destroy
        
        expect(Spree::Taxonomy.find_by(id: taxonomy_id)).to be_nil
        taxon_ids.each do |taxon_id|
          expect(Spree::Taxon.find_by(id: taxon_id)).to be_nil
        end
      end
    end

    it 'handles multiple taxonomies per store' do
      ActsAsTenant.with_tenant(store) do
        categories = Spree::Taxonomy.create!(name: 'Test Categories', position: 1)
        brands = Spree::Taxonomy.create!(name: 'Test Brands', position: 2)
        collections = Spree::Taxonomy.create!(name: 'Test Collections', position: 3)
        
        expect(Spree::Taxonomy.count).to eq(6) # 3 default + 3 test taxonomies
        expect(Spree::Taxonomy.pluck(:name)).to include(
          'Test Categories', 'Test Brands', 'Test Collections'
        )
        
        # Each taxonomy has its own root taxon
        expect(categories.root.name).to eq('Test Categories')
        expect(brands.root.name).to eq('Test Brands')
        expect(collections.root.name).to eq('Test Collections')
      end
    end
  end
end