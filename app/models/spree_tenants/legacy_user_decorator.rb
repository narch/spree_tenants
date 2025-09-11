module SpreeTenants
  module LegacyUserDecorator
    def self.prepended(base)
      base.class_eval do
        # LegacyUser specific configuration if needed
        # acts_as_tenant is applied by engine.rb for all models with store_id
      end
    end
  end
end

if defined?(Spree::LegacyUser)
  Spree::LegacyUser.prepend(SpreeTenants::LegacyUserDecorator)
end