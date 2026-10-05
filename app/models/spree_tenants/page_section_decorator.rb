module SpreeTenants
  module PageSectionDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::StoreIdInheritance

        inherit_store_id_from :pageable
      end
    end

    # Spree delegates #store to pageable, but the admin builds a new section
    # before assigning its page. Its ResourceController then calls
    # ensure_current_store, which needs #store to be nil-safe at that point.
    def store
      return super if pageable.present?
      return if store_id.blank?

      Spree::Store.unscoped.find_by(id: store_id)
    end
  end
end

Spree::PageSection.prepend(SpreeTenants::PageSectionDecorator)
