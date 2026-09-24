module SpreeTenants
  module ProductDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::DirectStoreOwnership

        owned_directly_by_store through: :store_products

        # Replace Spree's global slug validation with a store-scoped one.
        _validators.delete(:slug)
        slug_callbacks = _validate_callbacks.select do |callback|
          callback.filter.respond_to?(:attributes) && callback.filter.attributes == [:slug]
        end
        slug_callbacks.each { |callback| _validate_callbacks.delete(callback) }

        validates :slug, presence: true, uniqueness: {
          scope: :store_id,
          allow_blank: true,
          case_sensitive: true
        }

        friendly_id :slug_candidates, use: [:history, :scoped, :mobility], scope: :store_id

        validate :taxons_belong_to_same_store
        validate :properties_belong_to_same_store

        def self.spree_base_uniqueness_scope
          [:store_id]
        end

        private

        # Only in-memory records are checked; loading here would cache an empty
        # association. Persisted links are validated by Classification and
        # ProductProperty.
        def taxons_belong_to_same_store
          return if store_id.blank?

          in_memory = association(:taxons).target + association(:classifications).target.map(&:taxon)
          foreign = in_memory.compact.any? { |taxon| taxon.store_id.present? && taxon.store_id != store_id }
          errors.add(:taxons, 'must belong to the same store as the product') if foreign
        end

        def properties_belong_to_same_store
          return if store_id.blank?

          in_memory = association(:properties).target + association(:product_properties).target.map(&:property)
          foreign = in_memory.compact.any? { |property| property.store_id.present? && property.store_id != store_id }
          errors.add(:properties, 'must belong to the same store as the product') if foreign
        end
      end
    end
  end
end

Spree::Product.prepend(SpreeTenants::ProductDecorator)
