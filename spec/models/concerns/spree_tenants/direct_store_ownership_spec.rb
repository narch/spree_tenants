require 'spec_helper'

RSpec.describe SpreeTenants::DirectStoreOwnership do
  include_context 'multi_tenant_setup'

  describe 'Spree::Product' do
    it 'mirrors store_id into spree_products_stores on create' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      expect(product.store_id).to eq(store.id)
      expect(product.store_products.pluck(:store_id)).to eq([store.id])
      expect(product.stores).to eq([store])
    end

    it 'refuses a join row pointing at another store' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      expect { Spree::StoreProduct.create!(product: product, store: another_store) }
        .to raise_error(ActiveRecord::RecordInvalid, /must be the product store/)
      ActsAsTenant.without_tenant do
        expect(Spree::Product.for_store(another_store)).not_to include(product)
        expect(another_store.products).not_to include(product)
      end
    end

    it 'is race-safe: the join tables carry unique indexes' do
      indexes = ActiveRecord::Base.connection.indexes('spree_products_stores')
      expect(indexes).to include(have_attributes(unique: true, columns: %w[product_id store_id]))
    end

    it 'keeps Spree associations and scopes consistent with the direct column' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      ActsAsTenant.without_tenant do
        expect(Spree::Product.for_store(store)).to include(product)
        expect(Spree::Product.for_store(another_store)).not_to include(product)
        expect(store.products).to include(product)
        expect(another_store.products).not_to include(product)
        expect(store.store_products.map(&:product)).to include(product)
      end
    end

    it 'reports the owning store through store_ids and rejects writes naming another store' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      expect(product.store_ids).to eq([store.id])

      ActsAsTenant.without_tenant do
        expect { product.update!(store_ids: [another_store.id]) }.to raise_error(ActiveRecord::RecordInvalid, /exactly one store/)
        expect(product.update(store_ids: [store.id])).to be true
      end

      expect(product.reload.store_id).to eq(store.id)
      expect(product.store_products.pluck(:store_id)).to eq([store.id])
    end

    it 'does not require the Spree join-table presence validation' do
      product = ActsAsTenant.with_tenant(store) { build(:product, stores: []) }

      expect(product).to be_valid
    end
  end

  describe 'Spree::Promotion' do
    it 'refuses a join row pointing at another store' do
      promotion = ActsAsTenant.with_tenant(store) { Spree::Promotion.create!(name: 'Ten off', code: 'TEN') }

      expect { Spree::StorePromotion.create!(promotion: promotion, store: another_store) }
        .to raise_error(ActiveRecord::RecordInvalid, /must be the promotion store/)
    end

    it 'mirrors store_id into spree_promotions_stores' do
      promotion = ActsAsTenant.with_tenant(store) { Spree::Promotion.create!(name: 'Ten off', code: 'TEN') }

      expect(promotion.store_promotions.pluck(:store_id)).to eq([store.id])
      ActsAsTenant.without_tenant do
        expect(store.promotions).to include(promotion)
        expect(another_store.promotions).not_to include(promotion)
        expect(Spree::Promotion.for_store(store)).to include(promotion)
        expect(Spree::Promotion.for_store(another_store)).not_to include(promotion)
      end
    end
  end
end
