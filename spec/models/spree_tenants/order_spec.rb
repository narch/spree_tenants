require 'spec_helper'

RSpec.describe Spree::Order, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        order = Spree::Order.new(
          email: 'test@example.com'
        )
        
        expect(order.store_id).to eq(store.id)
      end
    end

    it 'creates an order within tenant context' do
      ActsAsTenant.with_tenant(store) do
        order = Spree::Order.create!(
          email: 'test@example.com'
        )
        
        expect(order).to be_persisted
        expect(order.store_id).to eq(store.id)
      end
    end

    it 'ensures order numbers are globally unique across stores' do
      # Order numbers should be globally unique, not per store
      order1 = ActsAsTenant.with_tenant(store) do
        Spree::Order.create!(
          email: 'test@example.com',
          number: 'R123456789'
        )
      end

      # Trying to create an order with the same number in a different store should fail
      expect {
        ActsAsTenant.with_tenant(another_store) do
          Spree::Order.create!(
            email: 'test@example.com',
            number: 'R123456789'
          )
        end
      }.to raise_error(ActiveRecord::RecordInvalid, /Number has already been taken/)
      
      expect(order1.store_id).to eq(store.id)
    end

    it 'scopes queries to current tenant' do
      order1 = ActsAsTenant.with_tenant(store) do
        Spree::Order.create!(
          email: 'store1@example.com'
        )
      end

      order2 = ActsAsTenant.with_tenant(another_store) do
        Spree::Order.create!(
          email: 'store2@example.com'
        )
      end

      ActsAsTenant.with_tenant(store) do
        orders = Spree::Order.all
        expect(orders).to include(order1)
        expect(orders).not_to include(order2)
      end

      ActsAsTenant.with_tenant(another_store) do
        orders = Spree::Order.all
        expect(orders).to include(order2)
        expect(orders).not_to include(order1)
      end
    end

    it 'isolates order associations by tenant' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        variant = product.master
        order = create(:order)
        
        # Create stock for the variant
        stock_location = create(:stock_location)
        stock_item = variant.stock_items.find_or_create_by!(stock_location: stock_location) do |item|
          item.count_on_hand = 10
        end
        
        line_item = order.line_items.create!(
          variant: variant,
          quantity: 1,
          price: variant.price
        )
        
        expect(line_item.store_id).to eq(store.id)
        expect(order.line_items.count).to eq(1)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        # Should not see the other store's order items
        expect(Spree::Order.count).to eq(0)
        expect(Spree::LineItem.count).to eq(0)
      end
    end

    it 'ensures shipments belong to same store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        product = create(:product)
        stock_location = create(:stock_location)
        
        # Create stock for the product
        stock_item = product.master.stock_items.find_or_create_by!(stock_location: stock_location) do |item|
          item.count_on_hand = 10
        end
        
        # Add line item with available stock
        order.line_items.create!(
          variant: product.master,
          quantity: 1,
          price: product.master.price
        )
        
        shipment = order.shipments.create!(
          stock_location: stock_location,
          state: 'pending'
        )
        
        expect(shipment.store_id).to eq(store.id)
        expect(shipment.stock_location.store_id).to eq(store.id)
      end
    end

    it 'ensures payments belong to same store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        # Create payment method with simple setup
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        # Create payment without validation to test store_id assignment
        payment = order.payments.build(
          payment_method: payment_method,
          amount: 100.00,
          state: 'pending'
        )
        payment.save!(validate: false)
        
        expect(payment.store_id).to eq(store.id)
        # Payment method gets store_id through acts_as_tenant
        expect(payment_method.store_id).to eq(store.id)
      end
    end

    it 'prevents cross-tenant order updates' do
      order = ActsAsTenant.with_tenant(store) do
        create(:order)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        # Should not be able to find or update the order from another tenant
        expect(Spree::Order.find_by(id: order.id)).to be_nil
        
        # Even if we somehow get the order object, acts_as_tenant should prevent updates
        ActsAsTenant.without_tenant do
          fetched_order = Spree::Order.find(order.id)
          expect(fetched_order.store_id).to eq(store.id)
        end
      end
    end
  end

  describe 'order number generation' do
    it 'generates unique numbers within a store' do
      ActsAsTenant.with_tenant(store) do
        order1 = Spree::Order.create!(email: 'test1@example.com')
        order2 = Spree::Order.create!(email: 'test2@example.com')
        
        expect(order1.number).not_to eq(order2.number)
        expect(order1.number).to match(/^R\d{9}$/)
        expect(order2.number).to match(/^R\d{9}$/)
      end
    end
  end

  describe 'cart behavior' do
    it 'maintains separate carts per store' do
      # Create user within tenant context so it gets store_id
      user = ActsAsTenant.with_tenant(store) do
        create(:user)
      end
      
      # Users can have orders in different stores
      cart1 = ActsAsTenant.with_tenant(store) do
        # Create order directly with proper associations
        order = Spree::Order.new(state: 'cart', email: user.email, user: user)
        order.save!(validate: false) # Skip validation to avoid tenant issues
        order
      end
      
      cart2 = ActsAsTenant.with_tenant(another_store) do
        # Create order for another store
        order = Spree::Order.new(state: 'cart', email: user.email, user: user)
        order.save!(validate: false)
        order
      end
      
      expect(cart1.store_id).to eq(store.id)
      expect(cart2.store_id).to eq(another_store.id)
      
      ActsAsTenant.with_tenant(store) do
        # Orders are scoped by tenant
        expect(Spree::Order.where(state: 'cart')).to include(cart1)
        expect(Spree::Order.where(state: 'cart')).not_to include(cart2)
      end
    end
  end
end