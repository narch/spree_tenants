module SpreeTenants
  class Configuration < Spree::Preferences::Configuration
    # Provision per-store records inside the transaction that creates a store.
    preference :provision_new_stores, :boolean, default: true
  end
end
