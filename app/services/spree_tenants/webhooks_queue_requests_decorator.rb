module SpreeTenants
  # Deliver only to the record's store, whatever the ambient tenant.
  module WebhooksQueueRequestsDecorator
    def self.prepended(base)
      base.class_eval do
        private

        def filtered_subscribers(event_name, webhook_payload_body, record, options)
          store_id = record.try(:store_id) || ActsAsTenant.current_tenant&.id

          unless store_id
            Rails.logger.warn "[spree_tenants] webhook #{event_name} skipped: no store for #{record.class} #{record.try(:id)}"
            return Spree::Webhooks::Subscriber.none
          end

          ActsAsTenant.without_tenant do
            Spree::Webhooks::Subscriber.active.with_urls_for(event_name).where(store_id: store_id)
          end
        end
      end
    end
  end
end

if defined?(Spree::Webhooks::Subscribers::QueueRequests)
  Spree::Webhooks::Subscribers::QueueRequests.prepend(SpreeTenants::WebhooksQueueRequestsDecorator)
end
