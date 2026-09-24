require 'spec_helper'

RSpec.describe SpreeTenants::TenantScoping do
  describe '.apply!' do
    it 'has been applied at boot' do
      expect(described_class).to be_applied
    end

    it 'scopes tenant-owned base models' do
      expect(Spree::Product).to respond_to(:scoped_by_tenant?)
      expect(Spree::Order).to respond_to(:scoped_by_tenant?)
      expect(Spree::Promotion).to respond_to(:scoped_by_tenant?)
      expect(Spree::Taxonomy).to respond_to(:scoped_by_tenant?)
    end

    it 'scopes the configured user classes whatever their namespace' do
      expect(described_class.user_classes).to include(Spree.user_class, Spree.admin_user_class)
      expect(Spree.user_class).to respond_to(:scoped_by_tenant?)
      expect(Spree.admin_user_class).to respond_to(:scoped_by_tenant?)
      expect(described_class.candidate_models).to include(Spree.user_class)
    end

    it 'validates user email uniqueness per store, not globally' do
      store = create(:store, name: 'Store 1', code: 'store1')
      another_store = create(:store, name: 'Store 2', code: 'store2')
      ActsAsTenant.with_tenant(store) { Spree.user_class.create!(email: 'same@example.com', password: 'password123') }

      duplicate = ActsAsTenant.with_tenant(another_store) { Spree.user_class.new(email: 'Same@example.com', password: 'password123') }
      expect(duplicate).to be_valid

      same_store = ActsAsTenant.with_tenant(store) { Spree.user_class.new(email: 'Same@example.com', password: 'password123') }
      expect(same_store).not_to be_valid
    end

    it 'leaves intentionally global models unscoped' do
      expect(Spree::Store).not_to respond_to(:scoped_by_tenant?)
      expect(Spree::Country).not_to respond_to(:scoped_by_tenant?)
      expect(Spree::PaymentMethod).not_to respond_to(:scoped_by_tenant?)
      expect(Spree::PaymentMethod::Check).not_to respond_to(:scoped_by_tenant?)
      expect(Spree::StoreProduct).not_to respond_to(:scoped_by_tenant?)
      expect(Spree::StorePromotion).not_to respond_to(:scoped_by_tenant?)
      expect(Spree::StorePaymentMethod).not_to respond_to(:scoped_by_tenant?)
    end

    it 'leaves no unexpected model with a store_id column unscoped' do
      unexpected = described_class.unscoped_models_with_store_id.reject { |model| described_class.global?(model) }

      expect(unexpected).to be_empty, "unscoped: #{unexpected.map(&:name).sort.join(', ')}"
    end

    it 'is idempotent' do
      product_scopes = Spree::Product.default_scopes.size
      product_callbacks = Spree::Product._validation_callbacks.count

      described_class.apply!

      expect(Spree::Product.default_scopes.size).to eq(product_scopes)
      expect(Spree::Product._validation_callbacks.count).to eq(product_callbacks)
    end

    it 'does not scope STI subclasses separately from their base class' do
      # The subclass inherits the base class default scope; it must not gain a second one.
      expect(Spree::ReimbursementType::StoreCredit.default_scopes.size).to eq(Spree::ReimbursementType.default_scopes.size)
      expect(Spree::ReimbursementType::StoreCredit).to respond_to(:scoped_by_tenant?)
    end
  end

  describe '.ready?' do
    it 'is true for a migrated, configured application' do
      expect(described_class.ready?).to be true
    end

    it 'is false when Spree has no user class configured' do
      allow(Spree).to receive(:user_class).with(constantize: false).and_return(nil)

      expect(described_class.ready?).to be false
    end
  end
end
