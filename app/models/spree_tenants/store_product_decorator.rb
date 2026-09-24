module SpreeTenants
  # Join rows mirror Product#store_id and may never point elsewhere.
  module StoreProductDecorator
    def self.prepended(base)
      base.class_eval do
        validate :store_matches_product
      end
    end

    private

    def store_matches_product
      return if product.nil? || product.store_id.nil? || store_id == product.store_id

      errors.add(:store, 'must be the product store')
    end
  end
end

Spree::StoreProduct.prepend(SpreeTenants::StoreProductDecorator)
