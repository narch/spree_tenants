# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require 'dotenv/load'

require File.expand_path('../dummy/config/environment.rb', __FILE__)

require 'spree_dev_tools/rspec/spec_helper'
require 'spree_tenants/factories'
require 'with_model'

Rails.application.eager_load!
SpreeTenants::TenantScoping.activate! or raise 'spree_tenants could not activate: is the dummy app migrated?'

Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.extend WithModel
end

def json_response
  case body = JSON.parse(response.body)
  when Hash
    body.with_indifferent_access
  when Array
    body
  end
end
