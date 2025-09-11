require 'spec_helper'

RSpec.describe Spree::Adjustment, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        adjustment = Spree::Adjustment.new(
          adjustable: order,
          order: order,
          amount: -5.00,
          label: 'Discount'
        )
        
        expect(adjustment.store_id).to eq(store.id)
      end
    end

    it 'creates adjustments within tenant context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        adjustment = Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -10.00,
          label: 'Promo Code',
          eligible: true
        )
        
        expect(adjustment).to be_persisted
        expect(adjustment.store_id).to eq(store.id)
        expect(adjustment.order.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      adjustment1 = ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -15.00,
          label: 'Store 1 Discount'
        )
      end

      adjustment2 = ActsAsTenant.with_tenant(another_store) do
        order = create(:order)
        
        Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -20.00,
          label: 'Store 2 Discount'
        )
      end

      ActsAsTenant.with_tenant(store) do
        adjustments = Spree::Adjustment.all
        expect(adjustments).to include(adjustment1)
        expect(adjustments).not_to include(adjustment2)
      end

      ActsAsTenant.with_tenant(another_store) do
        adjustments = Spree::Adjustment.all
        expect(adjustments).to include(adjustment2)
        expect(adjustments).not_to include(adjustment1)
      end
    end

    it 'prevents cross-tenant adjustment access' do
      adjustment = ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -10.00,
          label: 'Discount'
        )
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::Adjustment.find_by(id: adjustment.id)).to be_nil
      end
    end
  end

  describe 'adjustment types' do
    it 'handles order-level adjustments' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        # Order-level discount
        order_adjustment = Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -10.00,
          label: 'Order Discount',
          eligible: true
        )
        
        expect(order_adjustment.adjustable_type).to eq('Spree::Order')
        expect(order_adjustment.adjustable_id).to eq(order.id)
        expect(order.adjustments.count).to eq(1)
      end
    end

    it 'handles line item adjustments' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        product = create(:product)
        stock_location = create(:stock_location)
        product.master.stock_items.create!(
          stock_location: stock_location,
          count_on_hand: 10
        )
        
        line_item = order.line_items.create!(
          variant: product.master,
          quantity: 2,
          price: 20.00
        )
        
        # Line item discount
        item_adjustment = Spree::Adjustment.create!(
          adjustable: line_item,
          order: order,
          amount: -5.00,
          label: 'Item Discount',
          eligible: true
        )
        
        expect(item_adjustment.adjustable_type).to eq('Spree::LineItem')
        expect(item_adjustment.adjustable_id).to eq(line_item.id)
        expect(line_item.adjustments.count).to eq(1)
      end
    end

    it 'handles shipment adjustments' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        stock_location = create(:stock_location)
        
        shipment = order.shipments.create!(
          stock_location: stock_location,
          state: 'pending',
          cost: 10.00
        )
        
        # Shipping discount
        shipping_adjustment = Spree::Adjustment.create!(
          adjustable: shipment,
          order: order,
          amount: -3.00,
          label: 'Shipping Discount',
          eligible: true
        )
        
        expect(shipping_adjustment.adjustable_type).to eq('Spree::Shipment')
        expect(shipping_adjustment.adjustable_id).to eq(shipment.id)
        expect(shipment.adjustments.count).to eq(1)
      end
    end

    it 'handles tax adjustments' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        product = create(:product)
        stock_location = create(:stock_location)
        product.master.stock_items.create!(
          stock_location: stock_location,
          count_on_hand: 10
        )
        
        line_item = order.line_items.create!(
          variant: product.master,
          quantity: 1,
          price: 100.00
        )
        
        # Tax adjustment
        tax_adjustment = Spree::Adjustment.create!(
          adjustable: line_item,
          order: order,
          amount: 8.25,  # 8.25% tax
          label: 'Sales Tax',
          included: false,
          eligible: true
        )
        
        expect(tax_adjustment.amount).to eq(8.25)
        expect(tax_adjustment.included).to be false
      end
    end
  end

  describe 'promotion adjustments' do
    it 'applies promotions within store context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        # Create a promotion adjustment
        promotion = Spree::Promotion.create!(
          name: '10% Off',
          code: 'SAVE10'
        )
        
        adjustment = Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -10.00,
          label: promotion.name,
          source_type: 'Spree::PromotionAction',
          eligible: true
        )
        
        expect(adjustment.source_type).to eq('Spree::PromotionAction')
        expect(adjustment.eligible).to be true
        expect(promotion.store_id).to eq(store.id)
      end
    end

    it 'isolates promotion codes by store' do
      promo1 = ActsAsTenant.with_tenant(store) do
        Spree::Promotion.create!(
          name: 'Store 1 Promo',
          code: 'STORE1'
        )
      end
      
      promo2 = ActsAsTenant.with_tenant(another_store) do
        Spree::Promotion.create!(
          name: 'Store 2 Promo',
          code: 'STORE2'
        )
      end
      
      ActsAsTenant.with_tenant(store) do
        promotions = Spree::Promotion.all
        expect(promotions).to include(promo1)
        expect(promotions).not_to include(promo2)
      end
    end
  end

  describe 'adjustment calculations' do
    it 'calculates total adjustments per order' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        product = create(:product)
        stock_location = create(:stock_location)
        product.master.stock_items.create!(
          stock_location: stock_location,
          count_on_hand: 10
        )
        
        line_item = order.line_items.create!(
          variant: product.master,
          quantity: 2,
          price: 50.00
        )
        
        # Create multiple adjustments
        Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -10.00,
          label: 'Order Discount'
        )
        
        Spree::Adjustment.create!(
          adjustable: line_item,
          order: order,
          amount: -5.00,
          label: 'Item Discount'
        )
        
        Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: 8.00,
          label: 'Tax'
        )
        
        total_adjustments = order.all_adjustments.sum(:amount)
        expect(total_adjustments).to eq(-7.00)  # -10 - 5 + 8
      end
    end

    it 'groups adjustments by source' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        # Create adjustments from different sources
        3.times do |i|
          Spree::Adjustment.create!(
            adjustable: order,
            order: order,
            amount: -5.00,
            label: "Promo #{i}",
            source_type: 'Spree::PromotionAction'
          )
        end
        
        2.times do |i|
          Spree::Adjustment.create!(
            adjustable: order,
            order: order,
            amount: 10.00,
            label: "Tax #{i}",
            source_type: 'Spree::TaxRate'
          )
        end
        
        promo_adjustments = order.adjustments.where(source_type: 'Spree::PromotionAction')
        tax_adjustments = order.adjustments.where(source_type: 'Spree::TaxRate')
        
        expect(promo_adjustments.count).to eq(3)
        expect(tax_adjustments.count).to eq(2)
        expect(promo_adjustments.sum(:amount)).to eq(-15.00)
        expect(tax_adjustments.sum(:amount)).to eq(20.00)
      end
    end

    it 'handles eligible and ineligible adjustments' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        # Create eligible and ineligible adjustments
        eligible = Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -10.00,
          label: 'Valid Discount',
          eligible: true
        )
        
        ineligible = Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -20.00,
          label: 'Expired Discount',
          eligible: false
        )
        
        eligible_total = order.adjustments.eligible.sum(:amount)
        all_total = order.adjustments.sum(:amount)
        
        expect(eligible_total).to eq(-10.00)
        expect(all_total).to eq(-30.00)
      end
    end
  end

  describe 'adjustment updates' do
    it 'updates adjustments within store context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        adjustment = Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -5.00,
          label: 'Initial Discount'
        )
        
        # Update the adjustment - reload to ensure we see changes
        adjustment.amount = -10.00
        adjustment.label = 'Updated Discount'
        adjustment.save!
        adjustment.reload
        
        expect(adjustment.amount.to_f).to eq(-10.00)
        expect(adjustment.label).to eq('Updated Discount')
        expect(adjustment.store_id).to eq(store.id)
      end
    end

    it 'maintains store association on updates' do
      adjustment = ActsAsTenant.with_tenant(store) do
        order = create(:order)
        
        Spree::Adjustment.create!(
          adjustable: order,
          order: order,
          amount: -5.00,
          label: 'Discount'
        )
      end
      
      ActsAsTenant.with_tenant(store) do
        found_adjustment = Spree::Adjustment.find(adjustment.id)
        found_adjustment.amount = -7.50
        found_adjustment.save!
        found_adjustment.reload
        
        expect(found_adjustment.store_id).to eq(store.id)
        expect(found_adjustment.amount.to_f).to eq(-7.50)
      end
    end
  end
end