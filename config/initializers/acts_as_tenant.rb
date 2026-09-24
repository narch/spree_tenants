ActsAsTenant.configure do |config|
  # Requests and jobs always run with a tenant. Left off so console, rake and
  # seeding can work across stores; enable in the host app once those are wrapped.
  config.require_tenant = false
end
