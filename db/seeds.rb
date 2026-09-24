# Entry points for the spree_tenants:* rake tasks. Per-store provisioning lives
# in SpreeTenants::StoreProvisioner. Nothing runs on load.

module SpreeTenants
  class Seeds
    class << self
      # Create and provision a store atomically.
      def create_store!(name:, code:, url:, **attributes)
        Spree::Store.transaction do
          store = ActsAsTenant.without_tenant do
            Spree::Store.create!(
              {
                name: name,
                code: code,
                url: url,
                mail_from_address: "noreply@#{url}",
                default_country: Spree::Country.find_by(iso: 'US') || Spree::Country.first,
                default_currency: 'USD'
              }.merge(attributes)
            )
          end

          puts "Created store: #{store.name} (ID: #{store.id})"
          seed_store(store)
          store
        end
      end

      def seed_store(store)
        SpreeTenants::StoreProvisioner.call(store, logger: method(:puts))
      end

      def seed_all_stores
        seed_global_data
        ActsAsTenant.without_tenant { Spree::Store.find_each { |store| seed_store(store) } }
      end

      def seed_global_data
        puts 'Seeding global data...'
        seed_countries
        seed_states
        puts 'Completed seeding global data'
      end

      private

      def seed_countries
        if Spree::Country.exists?
          puts '  Countries already exist, skipping...'
          return
        end

        puts "  Seeding countries using Spree's Countries seed service..."
        Spree::Seeds::Countries.call
      end

      def seed_states
        if Spree::State.exists?
          puts '  States already exist, skipping...'
          return
        end

        puts "  Seeding states using Spree's States seed service..."
        Spree::Seeds::States.call
      end
    end
  end
end
