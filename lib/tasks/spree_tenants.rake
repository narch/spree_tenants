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

  desc 'Create a new store with basic data (atomic: nothing is left behind if seeding fails)'
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

    store = SpreeTenants::Seeds.create_store!(name: name, code: code, url: url)

    puts 'Store created and seeded successfully!'
    puts "Store ID: #{store.id}"
    puts "Store Code: #{store.code}"
    puts "Store URL: #{store.url}"
  end

  desc 'Create an admin user for a store (staff are per store and never shared)'
  task :create_admin, [:store_code, :email, :password] => :environment do |_task, args|
    require_relative '../spree_tenants/engine'

    store_code, email, password = args.values_at(:store_code, :email, :password)

    if [store_code, email, password].any?(&:blank?)
      puts 'Usage: rake spree_tenants:create_admin["store-code","admin@example.com","password"]'
      exit 1
    end

    store = ActsAsTenant.without_tenant { Spree::Store.find_by(code: store_code) }

    if store.nil?
      puts "Store with code '#{store_code}' not found"
      exit 1
    end

    admin = SpreeTenants::StoreProvisioner.create_admin!(store, email: email, password: password)
    puts "Created admin #{admin.email} (ID: #{admin.id}) for store #{store.name} (#{store.code})"
  end

  desc 'Report which Spree models are tenant-scoped and which store_id tables are not'
  task verify: :environment do
    require_relative '../spree_tenants/engine'

    Rails.application.eager_load!
    SpreeTenants::TenantScoping.apply!

    scoped = SpreeTenants::TenantScoping.scoped_models.map(&:name).sort
    puts "Tenant-scoped models (#{scoped.size}):"
    scoped.each { |name| puts "  #{name}" }

    unscoped = SpreeTenants::TenantScoping.unscoped_models_with_store_id
    intentional, unexpected = unscoped.partition { |model| SpreeTenants::TenantScoping.global?(model) }

    puts "\nIntentionally global models with a store_id column (#{intentional.size}):"
    intentional.map(&:name).sort.each { |name| puts "  #{name}" }

    if unexpected.any?
      puts "\nUNEXPECTED unscoped models with a store_id column (#{unexpected.size}):"
      unexpected.map(&:name).sort.each { |name| puts "  #{name}" }
      exit 1
    else
      puts "\nNo unexpected unscoped models."
    end
  end
end
