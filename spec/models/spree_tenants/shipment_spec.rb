require 'spec_helper'

RSpec.describe Spree::Shipment, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location)
        
        shipment = Spree::Shipment.new(
          order: order,
          stock_location: stock_location,
          state: 'pending'
        )
        
        expect(shipment.store_id).to eq(store.id)
      end
    end

    it 'creates shipments within tenant context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location)
        
        shipment = Spree::Shipment.create!(
          order: order,
          stock_location: stock_location,
          state: 'pending',
          cost: 10.00
        )
        
        expect(shipment).to be_persisted
        expect(shipment.store_id).to eq(store.id)
        expect(shipment.order.store_id).to eq(store.id)
        expect(shipment.stock_location.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      shipment1 = ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location, name: 'Store 1 Warehouse')
        
        Spree::Shipment.create!(
          order: order,
          stock_location: stock_location,
          state: 'pending',
          tracking: 'TRACK123'
        )
      end

      shipment2 = ActsAsTenant.with_tenant(another_store) do
        order = create(:order)
        stock_location = create(:stock_location, name: 'Store 2 Warehouse')
        
        Spree::Shipment.create!(
          order: order,
          stock_location: stock_location,
          state: 'pending',
          tracking: 'TRACK456'
        )
      end

      ActsAsTenant.with_tenant(store) do
        shipments = Spree::Shipment.all
        expect(shipments).to include(shipment1)
        expect(shipments).not_to include(shipment2)
      end

      ActsAsTenant.with_tenant(another_store) do
        shipments = Spree::Shipment.all
        expect(shipments).to include(shipment2)
        expect(shipments).not_to include(shipment1)
      end
    end

    it 'prevents cross-tenant shipment access' do
      shipment = ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location)
        
        Spree::Shipment.create!(
          order: order,
          stock_location: stock_location,
          state: 'pending'
        )
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::Shipment.find_by(id: shipment.id)).to be_nil
      end
    end

    it 'ensures order and stock location belong to same store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location)
        
        shipment = Spree::Shipment.create!(
          order: order,
          stock_location: stock_location,
          state: 'pending'
        )
        
        expect(shipment.order.store_id).to eq(store.id)
        expect(shipment.stock_location.store_id).to eq(store.id)
        expect([shipment.store_id, shipment.order.store_id, shipment.stock_location.store_id].uniq.size).to eq(1)
      end
    end
  end

  describe 'inventory allocation' do
    it 'allocates inventory within store context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        product = create(:product)
        stock_location = create(:stock_location)
        
        # Create stock
        stock_item = product.master.stock_items.create!(
          stock_location: stock_location,
          count_on_hand: 10
        )
        
        # Create line item
        line_item = order.line_items.create!(
          variant: product.master,
          quantity: 2,
          price: product.price
        )
        
        # Create shipment
        shipment = order.shipments.create!(
          stock_location: stock_location,
          state: 'pending'
        )
        
        # Create inventory units for the shipment
        2.times do
          shipment.inventory_units.create!(
            order: order,
            variant: product.master,
            line_item: line_item,
            state: 'on_hand'
          )
        end
        
        expect(shipment.inventory_units.count).to eq(2)
        expect(shipment.inventory_units.pluck(:store_id).uniq).to eq([store.id])
      end
    end

    it 'tracks inventory units per store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        product = create(:product)
        stock_location = create(:stock_location)
        
        # Create stock
        stock_item = product.master.stock_items.create!(
          stock_location: stock_location,
          count_on_hand: 10
        )
        
        line_item = order.line_items.create!(
          variant: product.master,
          quantity: 3,
          price: product.price
        )
        
        shipment = order.shipments.create!(
          stock_location: stock_location,
          state: 'pending'
        )
        
        # Create inventory units in different states
        shipment.inventory_units.create!(
          order: order,
          variant: product.master,
          line_item: line_item,
          state: 'on_hand'
        )
        
        shipment.inventory_units.create!(
          order: order,
          variant: product.master,
          line_item: line_item,
          state: 'backordered'
        )
        
        shipment.inventory_units.create!(
          order: order,
          variant: product.master,
          line_item: line_item,
          state: 'shipped'
        )
        
        expect(shipment.inventory_units.where(state: 'on_hand').count).to eq(1)
        expect(shipment.inventory_units.where(state: 'backordered').count).to eq(1)
        expect(shipment.inventory_units.where(state: 'shipped').count).to eq(1)
      end
    end
  end

  describe 'shipping methods' do
    it 'uses shipping methods from same store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location)
        shipping_category = create(:shipping_category)
        
        # Create shipping method with required fields
        calculator = Spree::Calculator::Shipping::FlatRate.create!(
          preferences: { amount: 5.0 }
        )
        
        shipping_method = Spree::ShippingMethod.create!(
          name: 'Standard Shipping',
          admin_name: 'Standard',
          display_on: 'both',
          calculator: calculator,
          shipping_categories: [shipping_category]
        )
        
        shipment = order.shipments.create!(
          stock_location: stock_location,
          state: 'pending'
        )
        
        # Add shipping method to shipment
        shipping_rate = shipment.shipping_rates.build(
          shipping_method: shipping_method,
          selected: true,
          cost: 5.00
        )
        shipping_rate.save!(validate: false)
        
        expect(shipping_method.store_id).to eq(store.id)
        expect(shipment.shipping_rates.first.shipping_method.store_id).to eq(store.id)
      end
    end

    it 'calculates shipping costs within store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location)
        
        # Create multiple shipments
        shipment1 = order.shipments.create!(
          stock_location: stock_location,
          state: 'pending',
          cost: 10.00
        )
        
        shipment2 = order.shipments.create!(
          stock_location: stock_location,
          state: 'pending',
          cost: 15.00
        )
        
        total_shipping = order.shipments.sum(:cost)
        expect(total_shipping).to eq(25.00)
      end
    end
  end

  describe 'shipment states' do
    it 'tracks shipment states per store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location)
        
        # Create shipments in different states
        pending = order.shipments.create!(
          stock_location: stock_location,
          state: 'pending'
        )
        
        ready = order.shipments.create!(
          stock_location: stock_location,
          state: 'ready'
        )
        
        shipped = order.shipments.create!(
          stock_location: stock_location,
          state: 'shipped',
          shipped_at: Time.current,
          tracking: 'SHIPPED123'
        )
        
        expect(Spree::Shipment.where(state: 'pending').count).to eq(1)
        expect(Spree::Shipment.where(state: 'ready').count).to eq(1)
        expect(Spree::Shipment.where(state: 'shipped').count).to eq(1)
      end
    end

    it 'transitions states within store context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        product = create(:product)
        stock_location = create(:stock_location)
        
        # Create stock
        stock_item = product.master.stock_items.create!(
          stock_location: stock_location,
          count_on_hand: 5
        )
        
        line_item = order.line_items.create!(
          variant: product.master,
          quantity: 1,
          price: product.price
        )
        
        shipment = order.shipments.create!(
          stock_location: stock_location,
          state: 'pending'
        )
        
        # Add inventory unit
        shipment.inventory_units.create!(
          order: order,
          variant: product.master,
          line_item: line_item,
          state: 'on_hand'
        )
        
        # Transition states
        shipment.state = 'ready'
        shipment.save!(validate: false)
        expect(shipment.state).to eq('ready')
        
        shipment.state = 'shipped'
        shipment.shipped_at = Time.current
        shipment.save!(validate: false)
        expect(shipment.state).to eq('shipped')
        expect(shipment.shipped_at).not_to be_nil
      end
    end
  end

  describe 'tracking and fulfillment' do
    it 'manages tracking numbers per store' do
      tracking1 = ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location)
        
        shipment = order.shipments.create!(
          stock_location: stock_location,
          state: 'shipped',
          tracking: 'STORE1-12345'
        )
        
        shipment.tracking
      end
      
      tracking2 = ActsAsTenant.with_tenant(another_store) do
        order = create(:order)
        stock_location = create(:stock_location)
        
        shipment = order.shipments.create!(
          stock_location: stock_location,
          state: 'shipped',
          tracking: 'STORE2-67890'
        )
        
        shipment.tracking
      end
      
      expect(tracking1).to eq('STORE1-12345')
      expect(tracking2).to eq('STORE2-67890')
      
      ActsAsTenant.with_tenant(store) do
        # Should only see shipments from this store
        shipments_with_tracking = Spree::Shipment.where.not(tracking: nil)
        expect(shipments_with_tracking.pluck(:tracking)).to eq(['STORE1-12345'])
      end
    end

    it 'handles multiple stock locations per store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        # Create multiple stock locations
        warehouse1 = create(:stock_location, name: 'Warehouse 1')
        warehouse2 = create(:stock_location, name: 'Warehouse 2')
        
        # Create shipments from different locations
        shipment1 = order.shipments.create!(
          stock_location: warehouse1,
          state: 'pending'
        )
        
        shipment2 = order.shipments.create!(
          stock_location: warehouse2,
          state: 'pending'
        )
        
        expect(order.shipments.count).to eq(2)
        expect(order.shipments.map(&:stock_location)).to include(warehouse1, warehouse2)
        expect(order.shipments.pluck(:store_id).uniq).to eq([store.id])
      end
    end
  end
end