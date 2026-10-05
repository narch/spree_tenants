module SpreeTenants
  module PageBlockDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        inherit_store_id_from :section
      end
    end

    # Page blocks can be initialized before the page builder assigns their
    # section. Spree's delegated #store must remain safe during that window.
    def store
      return super if section.present?
      return if store_id.blank?

      Spree::Store.unscoped.find_by(id: store_id)
    end
  end
end

Spree::PageBlock.prepend(SpreeTenants::PageBlockDecorator)
