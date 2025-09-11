require 'spec_helper'

RSpec.describe Spree::StockLocation, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        stock_location = Spree::StockLocation.new(
          name: 'Main Warehouse',
          default: true
        )
        
        expect(stock_location.store_id).to eq(store.id)
      end
    end

    it 'creates a stock location within tenant context' do
      ActsAsTenant.with_tenant(store) do
        stock_location = Spree::StockLocation.create!(
          name: 'Main Warehouse',
          address1: '123 Main St',
          city: 'New York',
          state_name: 'NY',
          zipcode: '10001',
          phone: '555-1234',
          country: create(:country)
        )
        
        expect(stock_location).to be_persisted
        expect(stock_location.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      location1 = ActsAsTenant.with_tenant(store) do
        create(:stock_location, name: 'Store 1 Warehouse')
      end

      location2 = ActsAsTenant.with_tenant(another_store) do
        create(:stock_location, name: 'Store 2 Warehouse')
      end

      ActsAsTenant.with_tenant(store) do
        locations = Spree::StockLocation.all
        expect(locations).to include(location1)
        expect(locations).not_to include(location2)
      end

      ActsAsTenant.with_tenant(another_store) do
        locations = Spree::StockLocation.all
        expect(locations).to include(location2)
        expect(locations).not_to include(location1)
      end
    end

    it 'allows multiple default locations per store' do
      # Each store can have its own default location
      location1 = ActsAsTenant.with_tenant(store) do
        create(:stock_location, name: 'Store 1 Default', default: true)
      end

      location2 = ActsAsTenant.with_tenant(another_store) do
        create(:stock_location, name: 'Store 2 Default', default: true)
      end

      expect(location1.default).to be true
      expect(location2.default).to be true
      expect(location1.store_id).to eq(store.id)
      expect(location2.store_id).to eq(another_store.id)
    end

    it 'isolates stock items by tenant' do
      product = ActsAsTenant.with_tenant(store) do
        create(:product)
      end
      
      location1 = ActsAsTenant.with_tenant(store) do
        create(:stock_location)
      end
      
      # Stock items are automatically created for variants in stock locations
      stock_item = ActsAsTenant.with_tenant(store) do
        product.master.stock_items.find_or_create_by!(stock_location: location1) do |item|
          item.count_on_hand = 10
        end
      end
      
      expect(stock_item.store_id).to eq(store.id)
      expect(stock_item.stock_location.store_id).to eq(store.id)
      
      ActsAsTenant.with_tenant(another_store) do
        # Should not see stock items from other stores
        expect(Spree::StockItem.count).to eq(0)
      end
    end

    it 'prevents cross-tenant stock location updates' do
      location = ActsAsTenant.with_tenant(store) do
        create(:stock_location, name: 'Original Name')
      end
      
      ActsAsTenant.with_tenant(another_store) do
        # Should not be able to find the location from another tenant
        expect(Spree::StockLocation.find_by(id: location.id)).to be_nil
      end
    end
  end

  describe 'stock management' do
    it 'manages stock movements within tenant' do
      ActsAsTenant.with_tenant(store) do
        location = create(:stock_location)
        product = create(:product)
        
        # Create initial stock
        stock_item = product.master.stock_items.find_or_create_by!(stock_location: location) do |item|
          item.count_on_hand = 0
        end
        
        # Create a stock movement
        stock_movement = stock_item.stock_movements.create!(
          quantity: 10,
          action: 'received'
        )
        
        expect(stock_movement.store_id).to eq(store.id)
        expect(stock_movement.stock_item.store_id).to eq(store.id)
      end
    end

    it 'tracks inventory separately per store' do
      product = ActsAsTenant.with_tenant(store) do
        create(:product, name: 'Shared Product Name')
      end
      
      another_product = ActsAsTenant.with_tenant(another_store) do
        create(:product, name: 'Shared Product Name')
      end
      
      # Set different stock levels in different stores
      ActsAsTenant.with_tenant(store) do
        location = create(:stock_location)
        stock_item = product.master.stock_items.find_or_create_by!(stock_location: location) do |item|
          item.count_on_hand = 100
        end
        expect(stock_item.count_on_hand).to eq(100)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        location = create(:stock_location)
        stock_item = another_product.master.stock_items.find_or_create_by!(stock_location: location) do |item|
          item.count_on_hand = 50
        end
        expect(stock_item.count_on_hand).to eq(50)
      end
    end
  end

  describe 'shipment associations' do
    it 'ensures shipments use stock locations from same store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        location = create(:stock_location)
        
        shipment = order.shipments.build(
          stock_location: location,
          state: 'pending'
        )
        shipment.save!(validate: false)
        
        expect(shipment.store_id).to eq(store.id)
        expect(shipment.stock_location.store_id).to eq(store.id)
      end
    end
  end
end