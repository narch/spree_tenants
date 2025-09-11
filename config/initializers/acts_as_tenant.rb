# Configure acts_as_tenant for Spree multi-tenancy
ActsAsTenant.configure do |config|
  # Don't require tenant by default - this allows global operations
  config.require_tenant = false
end