module SpreeTenants
  module TaxCategoryDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::CrossTenantValidation

        _validators[:name].reject! { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
        validates_uniqueness_scoped_to_store :name,
          scope: :deleted_at,
          case_sensitive: false

        # Spree caches the default category under one global key.
        def self.default
          store_id = ActsAsTenant.current_tenant&.id
          return find_by(is_default: true) unless store_id

          Rails.cache.fetch(SpreeTenants::TaxCategoryDecorator.default_cache_key(store_id)) do
            find_by(is_default: true)
          end
        end

        def set_default_category
          return unless is_default

          previous = self.class.where(is_default: true, store_id: store_id).where.not(id: id).first
          previous&.update_columns(is_default: false, updated_at: Time.current)
        end

        private

        def delete_cache
          Rails.cache.delete('default_tax_category')
          Rails.cache.delete(SpreeTenants::TaxCategoryDecorator.default_cache_key(store_id))
        end
      end
    end

    def self.default_cache_key(store_id)
      "default_tax_category/store-#{store_id || 'none'}"
    end
  end
end

Spree::TaxCategory.prepend(SpreeTenants::TaxCategoryDecorator)
