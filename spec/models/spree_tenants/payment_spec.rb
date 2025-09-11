require 'spec_helper'

RSpec.describe Spree::Payment, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        payment = Spree::Payment.new(
          order: order,
          payment_method: payment_method,
          amount: 100.00
        )
        
        expect(payment.store_id).to eq(store.id)
      end
    end

    it 'creates payments within tenant context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order, total: 50.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check', 
          active: true
        )
        
        payment = order.payments.build(
          payment_method: payment_method,
          amount: 50.00,
          state: 'pending'
        )
        payment.save!(validate: false)
        
        expect(payment).to be_persisted
        expect(payment.store_id).to eq(store.id)
        expect(payment.order.store_id).to eq(store.id)
        expect(payment.payment_method.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      payment1 = ActsAsTenant.with_tenant(store) do
        order = create(:order, total: 100.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Store 1 Check',
          active: true
        )
        
        payment = order.payments.build(
          payment_method: payment_method,
          amount: 100.00,
          state: 'pending'
        )
        payment.save!(validate: false)
        payment
      end

      payment2 = ActsAsTenant.with_tenant(another_store) do
        order = create(:order, total: 200.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Store 2 Check',
          active: true
        )
        
        payment = order.payments.build(
          payment_method: payment_method,
          amount: 200.00,
          state: 'pending'
        )
        payment.save!(validate: false)
        payment
      end

      ActsAsTenant.with_tenant(store) do
        payments = Spree::Payment.all
        expect(payments).to include(payment1)
        expect(payments).not_to include(payment2)
      end

      ActsAsTenant.with_tenant(another_store) do
        payments = Spree::Payment.all
        expect(payments).to include(payment2)
        expect(payments).not_to include(payment1)
      end
    end

    it 'prevents cross-tenant payment access' do
      payment = ActsAsTenant.with_tenant(store) do
        order = create(:order, total: 100.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        payment = order.payments.build(
          payment_method: payment_method,
          amount: 100.00,
          state: 'pending'
        )
        payment.save!(validate: false)
        payment
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::Payment.find_by(id: payment.id)).to be_nil
      end
    end

    it 'ensures order and payment method belong to same store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order, total: 100.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        payment = order.payments.build(
          payment_method: payment_method,
          amount: 100.00,
          state: 'pending'
        )
        payment.save!(validate: false)
        
        expect(payment.order.store_id).to eq(store.id)
        expect(payment.payment_method.store_id).to eq(store.id)
        expect([payment.store_id, payment.order.store_id, payment.payment_method.store_id].uniq.size).to eq(1)
      end
    end
  end

  describe 'payment processing' do
    it 'processes payments within store context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order, total: 100.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        payment = order.payments.build(
          payment_method: payment_method,
          amount: 100.00,
          state: 'pending'
        )
        payment.save!(validate: false)
        
        # Simulate payment processing
        payment.started_processing!
        expect(payment.state).to eq('processing')
        
        payment.complete!
        expect(payment.state).to eq('completed')
        
        # Payment log entries would also be scoped if they had store_id
        expect(payment.store_id).to eq(store.id)
      end
    end

    it 'tracks payment amounts independently per store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order, total: 80.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        # Create multiple payments
        payment1 = order.payments.build(
          payment_method: payment_method,
          amount: 50.00,
          state: 'completed'
        )
        payment1.save!(validate: false)
        
        payment2 = order.payments.build(
          payment_method: payment_method,
          amount: 30.00,
          state: 'completed'
        )
        payment2.save!(validate: false)
        
        total = order.payments.sum(:amount)
        expect(total).to eq(80.00)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        order = create(:order, total: 150.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        payment = order.payments.build(
          payment_method: payment_method,
          amount: 150.00,
          state: 'completed'
        )
        payment.save!(validate: false)
        
        total = Spree::Payment.sum(:amount)
        expect(total).to eq(150.00)
      end
    end

    it 'handles refunds within store context' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order, total: 100.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        payment = order.payments.build(
          payment_method: payment_method,
          amount: 100.00,
          state: 'completed'
        )
        payment.save!(validate: false)
        
        # Create a refund
        refund = payment.refunds.build(
          amount: 25.00,
          reason: create(:refund_reason, name: 'Return')
        )
        refund.save!(validate: false)
        
        expect(refund.payment.store_id).to eq(store.id)
        expect(payment.refunds.sum(:amount)).to eq(25.00)
      end
    end
  end

  describe 'payment methods' do
    it 'uses payment methods from same store only' do
      method1 = ActsAsTenant.with_tenant(store) do
        Spree::PaymentMethod::Check.create!(
          name: 'Store 1 Check',
          active: true
        )
      end
      
      method2 = ActsAsTenant.with_tenant(another_store) do
        Spree::PaymentMethod::Check.create!(
          name: 'Store 2 Check',
          active: true
        )
      end
      
      ActsAsTenant.with_tenant(store) do
        methods = Spree::PaymentMethod.all
        expect(methods).to include(method1)
        expect(methods).not_to include(method2)
        
        # Can only create payments with methods from this store
        order = create(:order, total: 100.00)
        payment = order.payments.build(
          payment_method: method1,
          amount: 100.00,
          state: 'pending'
        )
        payment.save!(validate: false)
        
        expect(payment.payment_method).to eq(method1)
      end
    end

    it 'filters available payment methods by store' do
      ActsAsTenant.with_tenant(store) do
        # Create multiple payment methods
        credit_card = Spree::PaymentMethod::Check.create!(
          name: 'Credit Card',
          active: true
        )
        
        check = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        inactive = Spree::PaymentMethod::Check.create!(
          name: 'Inactive Method',
          active: false
        )
        
        active_methods = Spree::PaymentMethod.where(active: true)
        expect(active_methods.count).to eq(2)
        expect(active_methods).to include(credit_card, check)
        expect(active_methods).not_to include(inactive)
      end
    end
  end

  describe 'payment states' do
    it 'tracks payment states per store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order, total: 175.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        # Create payments in different states
        pending = order.payments.build(
          payment_method: payment_method,
          amount: 50.00,
          state: 'pending'
        )
        pending.save!(validate: false)
        
        completed = order.payments.build(
          payment_method: payment_method,
          amount: 100.00,
          state: 'completed'
        )
        completed.save!(validate: false)
        
        failed = order.payments.build(
          payment_method: payment_method,
          amount: 25.00,
          state: 'failed'
        )
        failed.save!(validate: false)
        
        expect(Spree::Payment.where(state: 'pending').count).to eq(1)
        expect(Spree::Payment.where(state: 'completed').count).to eq(1)
        expect(Spree::Payment.where(state: 'failed').count).to eq(1)
      end
    end

    it 'calculates order payment totals within store' do
      ActsAsTenant.with_tenant(store) do
        order = create(:order, total: 100.00)
        payment_method = Spree::PaymentMethod::Check.create!(
          name: 'Check',
          active: true
        )
        
        # Create multiple payments
        p1 = order.payments.build(
          payment_method: payment_method,
          amount: 50.00,
          state: 'completed'
        )
        p1.save!(validate: false)
        
        p2 = order.payments.build(
          payment_method: payment_method,
          amount: 30.00,
          state: 'completed'
        )
        p2.save!(validate: false)
        
        p3 = order.payments.build(
          payment_method: payment_method,
          amount: 20.00,
          state: 'pending'
        )
        p3.save!(validate: false)
        
        completed_total = order.payments.where(state: 'completed').sum(:amount)
        expect(completed_total).to eq(80.00)
        
        all_total = order.payments.sum(:amount)
        expect(all_total).to eq(100.00)
      end
    end
  end
end