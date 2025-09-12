# Seeds for SpreeTenants extension
# This file provides methods to seed data for specific tenants
# Based on Spree's core seeds but adapted for multi-tenancy

module SpreeTenants
  class Seeds
    class << self
      # Seed data for a specific store/tenant
      # Usage: SpreeTenants::Seeds.seed_store(store)
      def seed_store(store)
        ActsAsTenant.with_tenant(store) do
          puts "Seeding data for store: #{store.name} (#{store.code})"
          
          # Core data needed for each tenant (based on Spree's seed structure)
          create_roles(store)
          create_shipping_categories(store)
          create_stock_locations(store)
          create_tax_categories(store)
          create_zones(store)
          create_payment_methods(store)
          create_store_credit_categories(store)
          create_default_reimbursement_types(store)
          create_returns_environment(store)
          create_taxonomies(store)
          create_digital_delivery(store)
          
          puts "Completed seeding for store: #{store.name}"
        end
      end
      
      # Seed all existing stores
      def seed_all_stores
        # First seed global data
        seed_global_data
        
        # Then seed each store
        Spree::Store.find_each do |store|
          seed_store(store)
        end
      end
      
      # Seed global data that all stores share
      def seed_global_data
        puts "Seeding global data..."
        
        # These are global and should not be scoped to stores
        seed_countries
        seed_states
        
        puts "Completed seeding global data"
      end
      
      private
      
      def create_roles(store)
        puts "  Creating roles..."
        
        # Note: Roles might be global, but adding store_id for consistency
        # These should match Spree's core roles
        role_names = %w[admin user]
        
        role_names.each do |name|
          Spree::Role.find_or_create_by!(name: name, store_id: store.id) if Spree::Role.column_names.include?('store_id')
        end
      end
      
      def create_shipping_categories(store)
        puts "  Creating shipping categories..."
        
        # Based on Spree's shipping_categories.rb seed
        Spree::ShippingCategory.find_or_create_by!(name: "Default #{store.code}", store_id: store.id)
        Spree::ShippingCategory.find_or_create_by!(name: "Digital #{store.code}", store_id: store.id)
      end
      
      def create_stock_locations(store)
        puts "  Creating stock locations..."
        
        # Based on Spree's stock_locations.rb seed
        Spree::StockLocation.find_or_create_by!(
          name: "#{store.name} Default",
          store_id: store.id,
          default: true,
          country: store.default_country,
          state: store.default_country&.states&.first,
          city: 'Default City',
          address1: '123 Default Street',
          zipcode: '12345'
        )
      end
      
      def create_tax_categories(store)
        puts "  Creating tax categories..."
        
        # Based on Spree's tax_categories.rb seed - just create default
        Spree::TaxCategory.find_or_create_by!(
          name: 'Default',
          store_id: store.id
        ) do |tax_cat|
          tax_cat.is_default = true
          tax_cat.description = 'Default tax category'
        end
      end
      
      def create_zones(store)
        puts "  Creating zones..."
        
        # Based on Spree's zones.rb seed - create North America zone as example
        country = store.default_country
        if country
          zone = Spree::Zone.find_or_create_by!(
            name: "#{country.name}",
            kind: 'country',
            store_id: store.id
          )
          
          Spree::ZoneMember.find_or_create_by!(
            zone: zone,
            zoneable: country
          ) if Spree::ZoneMember.column_names.include?('store_id')
        end
      end
      
      def create_payment_methods(store)
        puts "  Creating payment methods..."
        
        # Skip payment methods creation for now since they're complex and store-specific
        # Payment methods should be configured manually for each store based on their needs
        puts "    Skipping payment methods - configure manually per store requirements"
      end
      
      def create_store_credit_categories(store)
        puts "  Creating store credit categories..."
        
        # Based on Spree's store_credit_categories.rb seed
        categories = [
          { name: 'Default', store_id: store.id },
          { name: 'Non-expiring', store_id: store.id },
          { name: 'Expiring', store_id: store.id }
        ]
        
        categories.each do |attrs|
          Spree::StoreCreditCategory.find_or_create_by!(attrs) if defined?(Spree::StoreCreditCategory)
        end
      end
      
      def create_default_reimbursement_types(store)
        puts "  Creating reimbursement types..."
        
        # Based on Spree's default_reimbursement_types.rb seed
        types = [
          { name: 'Store Credit', store_id: store.id, active: true, mutable: false },
          { name: 'Original', store_id: store.id, active: true, mutable: false }
        ]
        
        types.each do |attrs|
          Spree::ReimbursementType.find_or_create_by!(name: attrs[:name], store_id: attrs[:store_id]) do |rt|
            rt.active = attrs[:active]
            rt.mutable = attrs[:mutable]
          end if defined?(Spree::ReimbursementType) && Spree::ReimbursementType.column_names.include?('store_id')
        end
      end
      
      def create_returns_environment(store)
        puts "  Creating returns environment..."
        
        # Based on Spree's returns_environment.rb seed
        # This might create return authorization reasons, return reasons, etc.
        # Only create if the models have store_id columns
        
        if defined?(Spree::ReturnReason) && Spree::ReturnReason.column_names.include?('store_id')
          reasons = ['Defective', 'Wrong Item', 'No Longer Needed', 'Damaged in Transit']
          reasons.each do |reason|
            Spree::ReturnReason.find_or_create_by!(name: reason, store_id: store.id)
          end
        end
      end
      
      def create_taxonomies(store)
        puts "  Creating taxonomies..."
        
        # Create main categories taxonomy (simpler version)
        taxonomy = Spree::Taxonomy.find_or_create_by!(
          name: 'Categories',
          store_id: store.id
        )
        
        # Create some basic taxons
        root = taxonomy.root
        
        ['Point of Sale', 'Apparel', 'Merchandise'].each do |category|
          Spree::Taxon.find_or_create_by!(
            name: category,
            taxonomy: taxonomy,
            parent: root,
            store_id: store.id
          )
        end
      end
      
      def create_digital_delivery(store)
        puts "  Creating digital delivery configuration..."
        
        # Based on Spree's digital_delivery.rb seed
        # This might set up digital delivery settings, but it's likely global config
        # Just placeholder for now
        puts "    (Digital delivery settings are typically global)"
      end
      
      # Global seed methods (not store-scoped) - use Spree's existing seed services
      
      def seed_countries
        if Spree::Country.exists?
          puts "  Countries already exist, skipping..."
          return
        end
        
        puts "  Seeding countries using Spree's Countries seed service..."
        
        if defined?(Spree::Seeds::Countries)
          Spree::Seeds::Countries.call
          puts "    Countries seeded successfully"
        else
          puts "    Spree::Seeds::Countries not available, skipping"
        end
      end
      
      def seed_states
        if Spree::State.exists?
          puts "  States already exist, skipping..."
          return
        end
        
        puts "  Seeding states using Spree's States seed service..."
        
        if defined?(Spree::Seeds::States)
          Spree::Seeds::States.call
          puts "    States seeded successfully"
        else
          puts "    Spree::Seeds::States not available, skipping"
        end
      end
    end
  end
end

# If running seeds directly, seed all stores
if defined?(Rails) && Rails.env.development?
  puts "Running SpreeTenants seeds..."
  SpreeTenants::Seeds.seed_all_stores
end