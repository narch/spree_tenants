module SpreeTenants
  module StockTransferDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        inherit_store_id_from :destination_location, :source_location
      end
    end
  end
end

Spree::StockTransfer.prepend(SpreeTenants::StockTransferDecorator)
