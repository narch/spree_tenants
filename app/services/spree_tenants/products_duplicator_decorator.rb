module SpreeTenants
  # Spree derives the copied SKU from Variant.unscoped; keep it in the product's store.
  module ProductsDuplicatorDecorator
    def call(product:, **options)
      @duplicating_store_id = product.store_id
      super
    end

    private

    def sku_generator(sku)
      return '' if sku.blank?

      last = Spree::Variant.unscoped
                           .where(store_id: @duplicating_store_id)
                           .where('sku like ?', "%#{sku}")
                           .order(:created_at)
                           .last
      "COPY OF #{last&.sku || sku}"
    end
  end
end

Spree::Products::Duplicator.prepend(SpreeTenants::ProductsDuplicatorDecorator) if defined?(Spree::Products::Duplicator)
