module SpreeTenants
  # Sets the tenant for every request from the request host, so Devise and
  # host-app controllers are covered too. The tenant is held until the response
  # body is closed (streamed responses) and the store is stashed in the env for
  # the controller decorators.
  class CurrentStoreMiddleware
    ENV_KEY = 'spree_tenants.store'.freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      SpreeTenants::TenantScoping.ensure_applied!

      previous = ActsAsTenant.current_tenant
      store = store_for(env)
      env[ENV_KEY] = store
      ActsAsTenant.current_tenant = store

      status, headers, body = @app.call(env)
      [status, headers, Rack::BodyProxy.new(body) { ActsAsTenant.current_tenant = previous }]
    rescue Exception
      ActsAsTenant.current_tenant = previous
      raise
    end

    private

    # Spree::Store.default can be an unsaved record; never serve that as a tenant.
    def store_for(env)
      finder = Spree::Dependencies.current_store_finder.constantize
      store = finder.new(url: env['SERVER_NAME']).execute
      store if store&.persisted?
    end
  end
end
