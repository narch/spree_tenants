module SpreeTenants
  module StockLocationDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::CrossTenantValidation

        if _validators[:name].any? { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
          _validators[:name].reject! { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
        end

        validates_uniqueness_scoped_to_store :name,
          scope: :deleted_at

        validate_same_store_for :stock_items
      end
    end

    # A location only holds stock for its own store's variants.
    def propagate_variant(variant)
      return if variant.store_id.present? && store_id.present? && variant.store_id != store_id

      super
    end

    private

    def ensure_one_default
      return unless default

      siblings = Spree::StockLocation.where(store_id: store_id).where.not(id: id)
      siblings.where(default: true).update_all(default: false)
      siblings.update_all(updated_at: Time.current)
    end
  end
end

Spree::StockLocation.prepend(SpreeTenants::StockLocationDecorator)
