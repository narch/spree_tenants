module MultiTenantTestHelper
  def ensure_shipping_category_for_store(store)
    ActsAsTenant.without_tenant do
      Spree::ShippingCategory.find_or_create_by(
        name: 'Default',
        store_id: store.id
      )
    end
  end
  
  def ensure_tax_category_for_store(store)
    ActsAsTenant.without_tenant do
      Spree::TaxCategory.find_or_create_by(
        name: 'Default',
        store_id: store.id,
        is_default: true
      )
    end
  end
  
  def ensure_stock_location_for_store(store)
    ActsAsTenant.without_tenant do
      Spree::StockLocation.find_or_create_by(
        name: 'Default',
        store_id: store.id,
        default: true
      )
    end
  end
  
  def ensure_default_taxonomies_for_store(store)
    ActsAsTenant.without_tenant do
      # Create default taxonomies that Spree creates automatically
      store.taxonomies.find_or_create_by(name: 'Categories')
      store.taxonomies.find_or_create_by(name: 'Brands')
      store.taxonomies.find_or_create_by(name: 'Collections')
    end
  end

  def ensure_default_records_for_store(store)
    ensure_shipping_category_for_store(store)
    ensure_tax_category_for_store(store)
    ensure_stock_location_for_store(store)
    ensure_default_taxonomies_for_store(store)
  end
end

# Shared context for multi-tenant tests
RSpec.shared_context "multi_tenant_setup" do
  let!(:country) do
    Spree::Country.find_by(iso: 'US') || create(:country_us)
  end

  let!(:store) do
    create(:store,
      name: "Store 1",
      code: "store1",
      default_country: country,
      default_currency: "USD"
    )
  end

  let!(:another_store) do
    create(:store,
      name: "Store 2",
      code: "store2",
      default_country: country,
      default_currency: "USD"
    )
  end

  before do
    ensure_default_records_for_store(store)
    ensure_default_records_for_store(another_store)
  end
end

RSpec.configure do |config|
  config.include MultiTenantTestHelper
  
  # config.include_context 'multi_tenant_setup'

  config.after(:each) do
    ActsAsTenant.current_tenant = nil
  end
end
