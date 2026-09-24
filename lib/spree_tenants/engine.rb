require 'acts_as_tenant'
require 'spree_tenants/tenant_scoping'
require 'spree_tenants/current_store_middleware'
require 'spree_tenants/store_provisioner'

module SpreeTenants
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_tenants'

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

    initializer 'spree_tenants.middleware' do |app|
      app.middleware.use SpreeTenants::CurrentStoreMiddleware
    end

    initializer 'spree_tenants.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << root.join('config/importmap.rb')
      app.config.importmap.cache_sweepers << root.join('app/javascript')
    end

    # Boot-time activation runs after_initialize so that engine locale files
    # are loaded first (Spree.t evaluated in class bodies would otherwise
    # capture "translation missing" markup). to_prepare only re-runs it on
    # code reloads in development.
    config.after_initialize { SpreeTenants::TenantScoping.activate! }

    config.to_prepare do
      SpreeTenants::TenantScoping.activate! if Rails.application.initialized?
    end
  end
end
