module TenantHelpers
  # Helper to set tenant for a group of tests
  def with_tenant(store)
    around do |example|
      described_class.with_tenant(store) do
        example.run
      end
    end
  end

  # Helper to ensure tenant is cleared after each test
  def ensure_tenant_cleared
    after do
      if defined?(described_class) && described_class.respond_to?(:clear_current_tenant!)
        described_class.clear_current_tenant!
      end
    end
  end

  # Helper to create multiple records across different stores
  def create_records_for_stores(model_class, stores, attributes = {})
    stores.map do |store|
      model_class.create!(attributes.merge(store_id: store.id))
    end
  end

  # Helper to assert records are properly scoped
  def expect_scoped_to_store(model_class, store)
    model_class.with_tenant(store) do
      records = model_class.all
      records.each do |record|
        expect(record.store_id).to eq(store.id)
      end
    end
  end
end

RSpec.configure do |config|
  config.include TenantHelpers
end