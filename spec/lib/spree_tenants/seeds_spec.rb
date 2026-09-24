require 'spec_helper'
require SpreeTenants::Engine.root.join('db/seeds')

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe SpreeTenants::Seeds do
  let!(:country) { Spree::Country.find_by(iso: 'US') || create(:country_us) }

  def quietly
    original = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original
  end

  describe '.create_store!' do
    it 'creates and seeds two stores with the same standard record names' do
      first = quietly { described_class.create_store!(name: 'First', code: 'first', url: 'first.example.com') }
      second = quietly { described_class.create_store!(name: 'Second', code: 'second', url: 'second.example.com') }

      [first, second].each do |store|
        ActsAsTenant.with_tenant(store) do
          expect(Spree::Role.pluck(:name)).to match_array(%w[admin user])
          expect(Spree::ShippingCategory.pluck(:name)).to match_array(%w[Default Digital])
          expect(Spree::StockLocation.where(default: true).count).to eq(1)
          expect(Spree::TaxCategory.where(is_default: true).count).to eq(1)
          expect(Spree::Zone.count).to eq(1)
          expect(Spree::ShippingMethod.count).to eq(1)
          expect(store.payment_methods.where(type: 'Spree::PaymentMethod::StoreCredit').count).to eq(1)
          expect(Spree::StoreCreditCategory.pluck(:name)).to match_array(['Default', 'Non-expiring', 'Expiring'])
          expect(Spree::RefundReason.pluck(:name)).to eq(['Return processing'])
          expect(Spree::ReturnAuthorizationReason.count).to eq(9)
          expect(Spree::ReimbursementType.pluck(:name)).to match_array(['Store Credit', 'Exchange', 'Original payment'])
          expect(Spree::Taxonomy.pluck(:name)).to match_array(%w[Categories Brands Collections])
        end
      end

      expect(store_scoped_counts(first)).to eq(store_scoped_counts(second))
    end

    it 'promotes an existing location and tax category when the store lost its defaults' do
      store = quietly { described_class.create_store!(name: 'First', code: 'first', url: 'first.example.com') }
      ActsAsTenant.without_tenant do
        Spree::StockLocation.where(store_id: store.id).update_all(default: false)
        Spree::TaxCategory.where(store_id: store.id).update_all(is_default: false)
      end

      expect { quietly { described_class.seed_store(store) } }.not_to raise_error

      ActsAsTenant.with_tenant(store) do
        expect(Spree::StockLocation.count).to eq(1)
        expect(Spree::StockLocation.first).to be_default
        expect(Spree::TaxCategory.where(name: 'Default').count).to eq(1)
        expect(Spree::TaxCategory.find_by(name: 'Default')).to be_is_default
      end
    end

    it 'derives a valid mail-from address from a url with a port' do
      store = quietly { described_class.create_store!(name: 'Local', code: 'local', url: 'second.lvh.me:3000') }

      expect(store.mail_from_address).to eq('noreply@second.lvh.me')
    end

    it 'is idempotent' do
      store = quietly { described_class.create_store!(name: 'First', code: 'first', url: 'first.example.com') }
      before = store_scoped_counts(store)

      quietly { described_class.seed_store(store) }

      expect(store_scoped_counts(store)).to eq(before)
    end

    it 'leaves nothing behind when seeding fails' do
      allow_any_instance_of(SpreeTenants::StoreProvisioner).to receive(:create_taxonomies).and_raise(ActiveRecord::RecordInvalid)

      counts = -> { ActsAsTenant.without_tenant { [Spree::Store.count, Spree::Role.count, Spree::StockLocation.count, Spree::Zone.count] } }

      expect do
        quietly { described_class.create_store!(name: 'Broken', code: 'broken', url: 'broken.example.com') }
      end.to raise_error(ActiveRecord::RecordInvalid).and(not_change { counts.call })

      expect(Spree::Store.find_by(code: 'broken')).to be_nil
    end
  end

  def store_scoped_counts(store)
    ActsAsTenant.with_tenant(store) do
      {
        roles: Spree::Role.count,
        shipping_categories: Spree::ShippingCategory.count,
        stock_locations: Spree::StockLocation.count,
        tax_categories: Spree::TaxCategory.count,
        zones: Spree::Zone.count,
        shipping_methods: Spree::ShippingMethod.count,
        store_credit_payment_methods: store.payment_methods.where(type: 'Spree::PaymentMethod::StoreCredit').count,
        store_credit_categories: Spree::StoreCreditCategory.count,
        refund_reasons: Spree::RefundReason.count,
        return_authorization_reasons: Spree::ReturnAuthorizationReason.count,
        reimbursement_types: Spree::ReimbursementType.count,
        taxonomies: Spree::Taxonomy.count
      }
    end
  end
end
