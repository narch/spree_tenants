module SpreeTenants
  module ShippingRateDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        # Inherit store_id from shipment, tax_rate or shipping_method
        inherit_store_id_from :shipment, :tax_rate, :shipping_method
      end
    end
  end
end

Spree::ShippingRate.prepend(SpreeTenants::ShippingRateDecorator)
