# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require 'dotenv/load'

require File.expand_path('../dummy/config/environment.rb', __FILE__)

require 'spree_dev_tools/rspec/spec_helper'
require 'spree_tenants/factories'
require 'with_model'

# Ensure acts_as_tenant is applied to Spree models
Rails.application.reloader.reload! if defined?(Rails.application.reloader)
Rails.application.eager_load!

# Trigger the to_prepare callbacks
Rails.configuration.to_prepare_blocks.each(&:call)

# Manually apply acts_as_tenant to Spree models since after_initialize doesn't run in tests
ActiveRecord::Base.descendants.each do |model|
  next unless model.name&.start_with?('Spree::')
  next if model.abstract_class?
  next if model == Spree::Store # Store is the tenant, not a scoped model
  
  begin
    if model.table_exists? && model.column_names.include?('store_id')
      unless model.reflect_on_association(:tenant_store)
        model.acts_as_tenant :store, foreign_key: 'store_id', class_name: 'Spree::Store'
        Rails.logger.info "Applied acts_as_tenant to #{model.name}"
      end
    end
  rescue StandardError => e
    Rails.logger.warn "Could not check or apply acts_as_tenant to #{model.name}: #{e.message}"
  end
end

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
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
