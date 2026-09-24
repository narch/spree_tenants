module SpreeTenants
  module PageLinkDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        inherit_store_id_from :parent
      end
    end
  end
end

Spree::PageLink.prepend(SpreeTenants::PageLinkDecorator)
