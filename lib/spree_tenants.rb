require 'spree_core'
require 'spree_extension'
require 'spree_tenants/engine'
require 'spree_tenants/version'
require 'spree_tenants/configuration'

module SpreeTenants
  def self.queue
    'default'
  end
end