require 'spec_helper'

RSpec.describe Spree::StockItem, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location = create(:stock_location)
        
        stock_item = Spree::StockItem.new(
          variant: product.master,
          stock_location: location,
          count_on_hand: 10
        )
        
        expect(stock_item.store_id).to eq(store.id)
      end
    end

    it 'creates stock items within tenant context' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location = create(:stock_location)
        
        stock_item = Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 10
        )
        
        expect(stock_item).to be_persisted
        expect(stock_item.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      item1 = ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location = create(:stock_location)
        Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 100
        )
      end

      item2 = ActsAsTenant.with_tenant(another_store) do
        product = create(:product)
        location = create(:stock_location)
        Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 200
        )
      end

      ActsAsTenant.with_tenant(store) do
        items = Spree::StockItem.all
        expect(items).to include(item1)
        expect(items).not_to include(item2)
        expect(items.sum(&:count_on_hand)).to eq(100)
      end

      ActsAsTenant.with_tenant(another_store) do
        items = Spree::StockItem.all
        expect(items).to include(item2)
        expect(items).not_to include(item1)
        expect(items.sum(&:count_on_hand)).to eq(200)
      end
    end

    it 'ensures variant and stock location belong to same store' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location = create(:stock_location)
        
        stock_item = Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 10
        )
        
        expect(stock_item.variant.store_id).to eq(store.id)
        expect(stock_item.stock_location.store_id).to eq(store.id)
        expect(stock_item.store_id).to eq(store.id)
      end
    end

    it 'prevents cross-tenant stock item access' do
      item = ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location = create(:stock_location)
        Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 10
        )
      end
      
      ActsAsTenant.with_tenant(another_store) do
        # Should not be able to find the stock item from another tenant
        expect(Spree::StockItem.find_by(id: item.id)).to be_nil
      end
    end
  end

  describe 'inventory tracking' do
    it 'tracks inventory adjustments per store' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location = create(:stock_location)
        
        stock_item = Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 10
        )
        
        # Adjust stock
        stock_item.adjust_count_on_hand(5)
        expect(stock_item.count_on_hand).to eq(15)
        
        # Create stock movement for the adjustment
        movement = stock_item.stock_movements.last
        expect(movement.store_id).to eq(store.id) if movement
      end
    end

    it 'handles backorders independently per store' do
      item1 = ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location = create(:stock_location)
        Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 0,
          backorderable: true
        )
      end

      item2 = ActsAsTenant.with_tenant(another_store) do
        product = create(:product)
        location = create(:stock_location)
        Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 0,
          backorderable: false
        )
      end

      expect(item1.backorderable).to be true
      expect(item2.backorderable).to be false
    end

    it 'calculates available inventory within store context' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location1 = create(:stock_location, name: 'Warehouse 1')
        location2 = create(:stock_location, name: 'Warehouse 2')
        
        # Create stock in multiple locations
        item1 = Spree::StockItem.create!(
          variant: product.master,
          stock_location: location1,
          count_on_hand: 50
        )
        
        item2 = Spree::StockItem.create!(
          variant: product.master,
          stock_location: location2,
          count_on_hand: 30
        )
        
        # Total stock for the variant in this store
        total_stock = product.master.stock_items.sum(:count_on_hand)
        expect(total_stock).to eq(80)
      end
    end
  end

  describe 'stock movements' do
    it 'creates stock movements with proper store association' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location = create(:stock_location)
        
        stock_item = Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 10
        )
        
        # Create a stock movement
        movement = stock_item.stock_movements.create!(
          quantity: 5,
          action: 'correction'
        )
        
        expect(movement.store_id).to eq(store.id)
        expect(movement.stock_item.store_id).to eq(store.id)
      end
    end

    it 'isolates stock movement history by store' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        location = create(:stock_location)
        stock_item = Spree::StockItem.create!(
          variant: product.master,
          stock_location: location,
          count_on_hand: 10
        )
        
        # Create movements
        stock_item.stock_movements.create!(quantity: 5, action: 'received')
        stock_item.stock_movements.create!(quantity: -3, action: 'sold')
      end
      
      ActsAsTenant.with_tenant(another_store) do
        # Should not see movements from other stores
        expect(Spree::StockMovement.count).to eq(0)
      end
      
      ActsAsTenant.with_tenant(store) do
        # Should see movements from this store
        expect(Spree::StockMovement.count).to eq(2)
      end
    end
  end
end