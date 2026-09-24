require 'spec_helper'

# Payment methods keep Spree's join-table ownership and are not tenant-scoped.
RSpec.describe Spree::PaymentMethod, type: :model do
  include_context 'multi_tenant_setup'

  it 'is not tenant scoped' do
    expect(Spree::PaymentMethod).not_to respond_to(:scoped_by_tenant?)
    expect(Spree::PaymentMethod::Check).not_to respond_to(:scoped_by_tenant?)
  end

  it 'is owned through the Spree store join table' do
    payment_method = Spree::PaymentMethod::Check.create!(name: 'Check', stores: [store])

    expect(store.payment_methods).to include(payment_method)
    expect(another_store.payment_methods).not_to include(payment_method)
    expect(payment_method.available_for_store?(store)).to be true
    expect(payment_method.available_for_store?(another_store)).to be false
  end

  it 'can be shared between stores' do
    payment_method = Spree::PaymentMethod::Check.create!(name: 'Shared', stores: [store, another_store])

    expect(store.payment_methods).to include(payment_method)
    expect(another_store.payment_methods).to include(payment_method)
  end

  it 'falls back to the default store when none is given (Spree behaviour)' do
    payment_method = Spree::PaymentMethod::Check.create!(name: 'Unassigned')

    expect(payment_method.stores).to eq([Spree::Store.default])
  end

  it 'is visible regardless of the current tenant' do
    payment_method = Spree::PaymentMethod::Check.create!(name: 'Check', stores: [store])

    ActsAsTenant.with_tenant(another_store) do
      expect(Spree::PaymentMethod.where(id: payment_method.id)).to exist
    end
  end

  it 'only offers the order store payment methods at checkout' do
    mine = Spree::PaymentMethod::Check.create!(name: 'Mine', stores: [store])
    Spree::PaymentMethod::Check.create!(name: 'Theirs', stores: [another_store])

    order = ActsAsTenant.with_tenant(store) { create(:order, store: store) }

    expect(order.collect_frontend_payment_methods).to eq([mine])
  end
end
