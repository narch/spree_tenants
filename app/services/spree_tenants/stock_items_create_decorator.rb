module SpreeTenants
  # Spree bulk-inserts stock items for every variant; restrict to the
  # location's store and stamp store_id (insert_all bypasses callbacks).
  module StockItemsCreateDecorator
    def self.prepended(base)
      base.class_eval do
        def call(stock_location:, variants_scope: Spree::Variant)
          variants_scope = variants_scope.where(store_id: stock_location.store_id)

          prepared_stock_items = variants_scope.ids.map do |variant_id|
            {
              'stock_location_id' => stock_location.id,
              'variant_id' => variant_id,
              'store_id' => stock_location.store_id,
              'backorderable' => stock_location.backorderable_default,
              'created_at' => Time.current,
              'updated_at' => Time.current
            }
          end

          if prepared_stock_items.any?
            stock_location.stock_items.insert_all(prepared_stock_items)
            variants_scope.touch_all
          end
        end
      end
    end
  end
end

if defined?(Spree::StockLocations::StockItems::Create)
  Spree::StockLocations::StockItems::Create.prepend(SpreeTenants::StockItemsCreateDecorator)
end
