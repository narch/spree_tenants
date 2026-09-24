module SpreeTenants
  module PageBlockDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        inherit_store_id_from :section
      end
    end
  end
end

Spree::PageBlock.prepend(SpreeTenants::PageBlockDecorator)
