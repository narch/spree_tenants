namespace :spree_tenants do
  desc 'Seed global data (countries, states)'
  task seed_global: :environment do
    require_relative '../spree_tenants/engine'
    require_relative '../../db/seeds'
    
    puts 'Seeding global data...'
    SpreeTenants::Seeds.seed_global_data
  end

  desc 'Seed data for all stores'
  task seed_all_stores: :environment do
    require_relative '../spree_tenants/engine'
    require_relative '../../db/seeds'
    
    puts 'Seeding data for all stores...'
    SpreeTenants::Seeds.seed_all_stores
  end
  
  desc 'Seed data for a specific store'
  task :seed_store, [:store_id] => :environment do |_task, args|
    require_relative '../spree_tenants/engine'
    require_relative '../../db/seeds'
    
    store_id = args[:store_id]
    
    if store_id.blank?
      puts 'Please provide a store_id: rake spree_tenants:seed_store[1]'
      exit 1
    end
    
    store = Spree::Store.find_by(id: store_id)
    
    if store.nil?
      puts "Store with ID #{store_id} not found"
      exit 1
    end
    
    puts "Seeding data for store: #{store.name} (ID: #{store.id})"
    SpreeTenants::Seeds.seed_store(store)
  end
  
  desc 'Seed data for a store by code'
  task :seed_store_by_code, [:store_code] => :environment do |_task, args|
    require_relative '../spree_tenants/engine'
    require_relative '../../db/seeds'
    
    store_code = args[:store_code]
    
    if store_code.blank?
      puts 'Please provide a store_code: rake spree_tenants:seed_store_by_code[my-store]'
      exit 1
    end
    
    store = Spree::Store.find_by(code: store_code)
    
    if store.nil?
      puts "Store with code '#{store_code}' not found"
      exit 1
    end
    
    puts "Seeding data for store: #{store.name} (#{store.code})"
    SpreeTenants::Seeds.seed_store(store)
  end
  
  desc 'Create a new store with basic data'
  task :create_store, [:name, :code, :url] => :environment do |_task, args|
    require_relative '../spree_tenants/engine'
    require_relative '../../db/seeds'
    
    name = args[:name]
    code = args[:code] 
    url = args[:url]
    
    if [name, code, url].any?(&:blank?)
      puts 'Usage: rake spree_tenants:create_store["Store Name","store-code","store.example.com"]'
      exit 1
    end
    
    # Create the store
    store = Spree::Store.create!(
      name: name,
      code: code,
      url: url,
      mail_from_address: "noreply@#{url}",
      default_country: Spree::Country.find_by(iso: 'US') || Spree::Country.first,
      default_currency: 'USD'
    )
    
    puts "Created store: #{store.name} (ID: #{store.id})"
    
    # Seed the store with basic data
    SpreeTenants::Seeds.seed_store(store)
    
    puts "Store created and seeded successfully!"
    puts "Store ID: #{store.id}"
    puts "Store Code: #{store.code}"
    puts "Store URL: #{store.url}"
  end
end