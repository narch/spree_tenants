module SpreeTenants
  module VariantDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        # Inherits store_id from the product and validates they match.
        inherit_store_id_from :product

        # Replace Spree's global SKU uniqueness with a store-scoped one.
        sku_uniqueness = _validate_callbacks.select do |callback|
          callback.filter.is_a?(ActiveRecord::Validations::UniquenessValidator) &&
            callback.filter.attributes == [:sku]
        end
        sku_uniqueness.each { |callback| _validate_callbacks.delete(callback) }
        _validators[:sku]&.reject! { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }

        validates :sku, uniqueness: {
          scope: :store_id,
          conditions: -> { where(deleted_at: nil) },
          case_sensitive: false
        }, allow_blank: true, unless: :disable_sku_validation?

        validate :option_values_belong_to_same_store

        private

        def option_values_belong_to_same_store
          return unless store_id.present?

          in_memory = association(:option_values).target + association(:option_value_variants).target.map(&:option_value)
          foreign = in_memory.compact.any? { |ov| ov.store_id.present? && ov.store_id != store_id }
          errors.add(:option_values, 'must belong to the same store as the variant') if foreign
        end

        # Only propagate into this store's stock locations.
        def create_stock_items
          Spree::StockLocation.where(propagate_all_variants: true, store_id: store_id).each do |stock_location|
            stock_location.propagate_variant(self)
          end
        end
      end
    end
  end
end

Spree::Variant.prepend(SpreeTenants::VariantDecorator)
