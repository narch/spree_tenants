module SpreeTenants
  module WebhooksEventDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        inherit_store_id_from :subscriber
      end
    end
  end
end

Spree::Webhooks::Event.prepend(SpreeTenants::WebhooksEventDecorator) if defined?(Spree::Webhooks::Event)
