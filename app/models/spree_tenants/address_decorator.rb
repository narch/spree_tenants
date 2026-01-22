module SpreeTenants
  module AddressDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

         # Inherit store_id from product or taxon
         inherit_store_id_from :user
      end
    end
  end
end

Spree::Address.prepend(SpreeTenants::AddressDecorator)