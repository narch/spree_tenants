module SpreeTenants
  module ZoneDecorator
    def self.prepended(base)
      base.class_eval do
        # Spree caches the default tax zone under one global key.
        def self.default_tax
          store_id = ActsAsTenant.current_tenant&.id
          return find_by(default_tax: true) unless store_id

          Rails.cache.fetch(SpreeTenants::ZoneDecorator.default_tax_cache_key(store_id)) do
            find_by(default_tax: true)
          end
        end

        private

        def nullify_checkout_zone
          Spree::Store.where(id: store_id, checkout_zone_id: id).find_each { |s| s.update(checkout_zone_id: nil) }
        end

        def remove_previous_default
          Spree::Zone.with_default_tax.where(store_id: store_id).where.not(id: id).update_all(default_tax: false)
          Rails.cache.delete('default_zone')
          Rails.cache.delete(SpreeTenants::ZoneDecorator.default_tax_cache_key(store_id))
        end
      end
    end

    def self.default_tax_cache_key(store_id)
      "default_tax/store-#{store_id || 'none'}"
    end
  end
end

Spree::Zone.prepend(SpreeTenants::ZoneDecorator)
