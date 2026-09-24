require 'spec_helper'

RSpec.describe Spree::Variant, type: :model do
  let(:store) { create(:store) }
  let(:another_store) { create(:store) }
  
  before do
    # Ensure default records exist for both stores
    ensure_default_records_for_store(store)
    ensure_default_records_for_store(another_store)

    expect(store).to be_valid, store.errors.full_messages.to_sentence
    expect(another_store).to be_valid, another_store.errors.full_messages.to_sentence
  end
  
  describe 'SKU uniqueness' do
    it 'allows same SKU in different stores' do
      product = create(:product, store_id: store.id)
      another_product = create(:product, store_id: another_store.id)

      ActsAsTenant.with_tenant(store) do
        create(:variant, sku: 'SKU-001', product: product)
      end

      ActsAsTenant.with_tenant(another_store) do
        variant = build(:variant, sku: 'SKU-001', product: another_product)
        expect(variant).to be_valid
      end
    end

    it 'prevents duplicate SKUs within the same store' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      ActsAsTenant.with_tenant(store) do
        create(:variant, sku: 'SKU-001', product: product)
        duplicate = build(:variant, sku: 'SKU-001', product: product)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:sku]).to include('has already been taken')
      end
    end

    it 'is case insensitive within a store' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      ActsAsTenant.with_tenant(store) do
        create(:variant, sku: 'sku-001', product: product)
        duplicate = build(:variant, sku: 'SKU-001', product: product)

        expect(duplicate).not_to be_valid
      end
    end

    it 'is also enforced by the database for concurrent writes' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      ActsAsTenant.with_tenant(store) do
        variant = create(:variant, sku: 'SKU-001', product: product)

        columns = { product_id: product.id, sku: 'sku-001', store_id: store.id, is_master: false,
                    created_at: Time.current, updated_at: Time.current }
        expect do
          Spree::Variant.insert_all!([columns])
        end.to raise_error(ActiveRecord::RecordNotUnique)
        expect(variant).to be_persisted
      end
    end

    it 'allows multiple blank SKUs' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      ActsAsTenant.with_tenant(store) do
        variant1 = create(:variant, sku: '', product: product)
        variant2 = build(:variant, sku: '', product: product)

        expect(variant1).to be_persisted
        expect(variant2).to be_valid
      end
    end

    it 'ignores deleted variants' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      ActsAsTenant.with_tenant(store) do
        deleted_variant = create(:variant, sku: 'SKU-001', product: product)
        deleted_variant.destroy

        new_variant = build(:variant, sku: 'SKU-001', product: product)
        expect(new_variant).to be_valid
      end
    end
  end

  describe 'cross-tenant validations' do
    describe '#option_values_belong_to_same_store' do
      it 'allows option values from same store' do
        product = ActsAsTenant.with_tenant(store) { create(:product) }
        variant = ActsAsTenant.with_tenant(store) { create(:variant, product: product) }
        
        store_option_type = ActsAsTenant.with_tenant(store) { create(:option_type) }
        store_option_value = ActsAsTenant.with_tenant(store) { create(:option_value, option_type: store_option_type) }
        
        ActsAsTenant.without_tenant do
          variant.option_values << store_option_value
          expect(variant).to be_valid
        end
      end
      
      it 'prevents option values from different stores' do
        product = ActsAsTenant.with_tenant(store) { create(:product) }
        variant = ActsAsTenant.with_tenant(store) { create(:variant, product: product) }
        
        another_store_option_type = ActsAsTenant.with_tenant(another_store) { create(:option_type) }
        another_store_option_value = ActsAsTenant.with_tenant(another_store) { create(:option_value, option_type: another_store_option_type) }
        
        ActsAsTenant.without_tenant do
          expect { variant.option_values << another_store_option_value }.to raise_error(ActiveRecord::RecordInvalid, /same store/)
          expect(variant.reload.option_values).not_to include(another_store_option_value)

          unsaved = build(:variant, product: product, store_id: store.id, option_values: [another_store_option_value])
          expect(unsaved).not_to be_valid
          expect(unsaved.errors[:option_values]).to include('must belong to the same store as the variant')
        end
      end
    end
  end
  
  describe 'master variant' do
    it 'inherits store_id from product' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        expect(product.master.store_id).to eq(store.id)
      end
    end
  end
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when creating variant' do
      ActsAsTenant.with_tenant(store) do
        product = create(:product)
        variant = create(:variant, product: product)
        expect(variant.store_id).to eq(store.id)
      end
    end
    
    it 'scopes variants to current tenant' do
      product1 = ActsAsTenant.with_tenant(store) { create(:product) }
      product2 = ActsAsTenant.with_tenant(another_store) { create(:product) }
      
      ActsAsTenant.with_tenant(store) do
        variant1 = create(:variant, product: product1)
      end
      
      ActsAsTenant.with_tenant(another_store) do
        variant2 = create(:variant, product: product2)
      end
      
      ActsAsTenant.with_tenant(store) do
        variants = Spree::Variant.all
        expect(variants.pluck(:store_id).uniq).to eq([store.id])
      end
    end
  end
end