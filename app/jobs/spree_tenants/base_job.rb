module SpreeTenants
  class BaseJob < Spree::BaseJob
    queue_as SpreeTenants.queue
  end
end
