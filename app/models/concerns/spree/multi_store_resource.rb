# frozen_string_literal: true

# Override Spree's MultiStoreResource concern
# 
# In the default Spree architecture, products and other resources can belong to 
# multiple stores via a many-to-many relationship. This concern handles that
# relationship and its validations.
#
# However, in our multi-tenant architecture using acts_as_tenant, each store
# is completely isolated as a tenant. Resources belong to exactly one store
# via the store_id foreign key, and acts_as_tenant handles all the scoping
# and assignment automatically.
#
# Therefore, we override this concern with an empty module to disable all
# the multi-store validations and callbacks that would conflict with our
# tenant-based approach.
module Spree
  module MultiStoreResource
    extend ActiveSupport::Concern
    
    # Empty module - all multi-store logic is handled by acts_as_tenant
  end
end