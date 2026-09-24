module SpreeTenants
  module PromotionDecorator
    def self.prepended(base)
      base.class_eval do
        include SpreeTenants::DirectStoreOwnership

        owned_directly_by_store through: :store_promotions

        def self.spree_base_uniqueness_scope
          [:store_id]
        end
      end
    end
  end
end

Spree::Promotion.prepend(SpreeTenants::PromotionDecorator)
