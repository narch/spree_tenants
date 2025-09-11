require 'acts_as_tenant'

module SpreeTenants
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_tenants'

    # use rspec for tests
    config.generators do |g|
      g.test_framework :rspec
    end

    initializer 'spree_tenants.environment', before: :load_config_initializers do |_app|
      SpreeTenants::Config = SpreeTenants::Configuration.new
    end

    initializer 'spree_tenants.assets' do |app|
      app.config.assets.paths << root.join('app/javascript')
      app.config.assets.paths << root.join('vendor/javascript')
      app.config.assets.paths << root.join('vendor/stylesheets')
      app.config.assets.precompile += %w[spree_tenants_manifest]
    end

    initializer 'spree_tenants.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << root.join('config/importmap.rb')
      # https://github.com/rails/importmap-rails?tab=readme-ov-file#sweeping-the-cache-in-development-and-test
      app.config.importmap.cache_sweepers << root.join('app/javascript')
    end

    # Apply acts_as_tenant to models directly
    config.after_initialize do
      Rails.application.eager_load!
      
      ActiveRecord::Base.descendants.each do |model|
        # Skip if it's not a Spree model
        next unless model.name&.start_with?('Spree::')
        next if model.abstract_class?
        next if model == Spree::Store # Store is the tenant, not a scoped model
        
        # Check if the model has a store_id column
        begin
          if model.table_exists? && model.column_names.include?('store_id')
            unless model.reflect_on_association(:tenant_store)
              # Apply acts_as_tenant directly to the model
              model.acts_as_tenant :store, foreign_key: 'store_id', class_name: 'Spree::Store'
              Rails.logger.info "Applied acts_as_tenant to #{model.name}"
            end
          end
        rescue StandardError => e
          Rails.logger.warn "Could not check or apply acts_as_tenant to #{model.name}: #{e.message}"
        end
      end
      
      # Fix Product slug validation after all decorators are loaded
      # This is necessary because Spree's validation gets added after our decorator
      if defined?(Spree::Product)
        Spree::Product._validators.delete(:slug)
        Spree::Product._validate_callbacks.each do |callback|
          if callback.filter.respond_to?(:attributes) && 
             callback.filter.is_a?(ActiveRecord::Validations::UniquenessValidator) &&
             callback.filter.attributes.include?(:slug)
            Spree::Product._validate_callbacks.delete(callback)
          end
        end
        
        # Re-add with proper scoping
        Spree::Product.validates :slug, presence: true, uniqueness: { 
          scope: :store_id,
          allow_blank: true, 
          case_sensitive: true
        }
      end
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
