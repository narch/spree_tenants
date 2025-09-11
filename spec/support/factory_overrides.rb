# Override Spree's product factory to work with our tenant-based approach
# The default factory tries to set the stores association, but we use store_id instead
FactoryBot.modify do
  factory :base_product do
    # Remove the stores association - we use store_id via acts_as_tenant
    stores { [] }
    
    # Don't create a default store - we create stores explicitly in tests
    before(:create) do |_product|
      create(:stock_location) unless Spree::StockLocation.any?
      # Remove: create(:store, default: true) unless Spree::Store.any?
    end
  end
end