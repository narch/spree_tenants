module SpreeTenants
  module PageSectionDecorator
    def self.prepended(base)
      base.class_eval do
        def store
          if (pg = try(:pageable))
            return pg.store if pg.respond_to?(:store)
          end
    
          tenant = ActsAsTenant.current_tenant
          return tenant if tenant.is_a?(Spree::Store)
    
          Spree::Store.try(:current) || Spree::Store.default
        end
      end
    end
  end
end

Spree::PageSection.prepend(SpreeTenants::PageSectionDecorator)