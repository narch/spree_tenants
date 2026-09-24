require 'spec_helper'

RSpec.describe Spree::TaxCategory, type: :model do
  include_context 'multi_tenant_setup'

  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  describe '.default' do
    it 'returns each store its own default even after another store primed the cache' do
      first = ActsAsTenant.with_tenant(store) { Spree::TaxCategory.where(is_default: true).first }
      second = ActsAsTenant.with_tenant(another_store) { Spree::TaxCategory.where(is_default: true).first }
      expect(first.store_id).to eq(store.id)
      expect(second.store_id).to eq(another_store.id)

      expect(ActsAsTenant.with_tenant(store) { Spree::TaxCategory.default }).to eq(first)
      expect(ActsAsTenant.with_tenant(another_store) { Spree::TaxCategory.default }).to eq(second)
      expect(ActsAsTenant.with_tenant(store) { Spree::TaxCategory.default }).to eq(first)
    end

    it 'invalidates the cache for the store whose default changed' do
      ActsAsTenant.with_tenant(store) do
        old_default = Spree::TaxCategory.default
        new_default = Spree::TaxCategory.create!(name: 'Reduced', is_default: true)

        expect(Spree::TaxCategory.default).to eq(new_default)
        expect(old_default.reload.is_default).to be false
      end
    end
  end

  describe '#set_default_category' do
    it 'does not unset another store default' do
      other_default = ActsAsTenant.with_tenant(another_store) { Spree::TaxCategory.default }

      ActsAsTenant.with_tenant(store) { Spree::TaxCategory.create!(name: 'Reduced', is_default: true) }

      expect(other_default.reload.is_default).to be true
    end
  end
end
