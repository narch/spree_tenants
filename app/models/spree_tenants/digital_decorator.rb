module SpreeTenants
  module DigitalDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        inherit_store_id_from :variant
      end
    end
  end
end

Spree::Digital.prepend(SpreeTenants::DigitalDecorator)
