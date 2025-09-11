FactoryBot.define do
  # Additional factory modifications for multi-tenant testing
  
  # Store factory modifications
  factory :store_with_products, parent: :store do
    transient do
      product_count { 3 }
    end
    
    after(:create) do |store, evaluator|
      ActsAsTenant.with_tenant(store) do
        create_list(:product, evaluator.product_count, store: store)
      end
    end
  end
  
  # Product factory with store association
  factory :product_with_store, parent: :product do
    store { Spree::Store.default || create(:store) }
    
    after(:create) do |product|
      product.master.update!(store_id: product.store_id) if product.master
    end
  end
  
  # Tenant-aware variant factory that doesn't auto-create option values
  factory :tenant_variant, class: 'Spree::Variant' do
    price { 19.99 }
    cost_price { 17.00 }
    sku { generate(:sku) }
    weight { rand(10..100) }
    height { rand(10..100) }
    width { rand(10..100) }
    depth { rand(10..100) }
    is_master { false }
    track_inventory { true }
    product
    
    # Don't auto-create option_values like the base Spree factory does
    # This allows our decorators to properly set store_id
    
    transient do
      create_stock { true }
    end
    
    before(:create) do |variant, evaluator|
      if evaluator.create_stock && !Spree::StockLocation.any?
        create(:stock_location, store_id: variant.product&.store_id || variant.store_id)
      end
    end
    
    after(:create) do |variant, evaluator|
      if evaluator.create_stock
        Spree::StockLocation.all.each do |stock_location|
          next if stock_location.stock_item(variant).present?
          stock_location.propagate_variant(variant)
        end
      end
    end
    
    trait :with_option_values do
      after(:create) do |variant|
        if variant.store_id
          ActsAsTenant.with_tenant(Spree::Store.find(variant.store_id)) do
            option_type = create(:option_type)
            option_value = create(:option_value, option_type: option_type)
            variant.option_values << option_value
          end
        end
      end
    end
  end
  
  # Multi-store test setup factory
  factory :multi_store_setup, class: Hash do
    skip_create
    
    transient do
      stores_count { 2 }
      products_per_store { 3 }
    end
    
    initialize_with do
      stores = create_list(:store, stores_count)
      
      stores.each do |store|
        ActsAsTenant.with_tenant(store) do
          create_list(:product, products_per_store, store: store)
        end
      end
      
      { stores: stores }
    end
  end
end