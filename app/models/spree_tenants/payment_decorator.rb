module SpreeTenants
  module PaymentDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        def self.spree_base_uniqueness_scope
          [:store_id]
        end

        inherit_store_id_from :order
      end
    end
  end
end

Spree::Payment.prepend(SpreeTenants::PaymentDecorator)
