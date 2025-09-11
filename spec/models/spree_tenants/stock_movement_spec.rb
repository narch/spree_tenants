require 'spec_helper'

RSpec.describe Spree::StockMovement, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        stock_location = create(:stock_location)
        stock_item = create(:stock_item, stock_location: stock_location)
        
        stock_movement = Spree::StockMovement.new(
          stock_item: stock_item,
          quantity: 10
        )
        
        expect(stock_movement.store_id).to eq(store.id)
      end
    end

    it 'creates stock movements within tenant context' do
      ActsAsTenant.with_tenant(store) do
        stock_location = create(:stock_location)
        stock_item = create(:stock_item, stock_location: stock_location)
        
        stock_movement = Spree::StockMovement.create!(
          stock_item: stock_item,
          quantity: 10
        )
        
        expect(stock_movement.store_id).to eq(store.id)
        expect(stock_movement.stock_item.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      ActsAsTenant.with_tenant(store) do
        stock_location = create(:stock_location)
        stock_item = create(:stock_item, stock_location: stock_location)
        
        stock_movement = Spree::StockMovement.create!(
          stock_item: stock_item,
          quantity: 10
        )
      end
      
      ActsAsTenant.with_tenant(another_store) do
        stock_location2 = create(:stock_location)
        stock_item2 = create(:stock_item, stock_location: stock_location2)
        
        stock_movement2 = Spree::StockMovement.create!(
          stock_item: stock_item2,
          quantity: 5
        )
      end
      
      ActsAsTenant.with_tenant(store) do
        expect(Spree::StockMovement.count).to eq(1)
        expect(Spree::StockMovement.first.quantity).to eq(10)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::StockMovement.count).to eq(1)
        expect(Spree::StockMovement.first.quantity).to eq(5)
      end
    end
  end
end
