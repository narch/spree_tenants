module SpreeTenants
  # Join rows mirror Promotion#store_id and may never point elsewhere.
  module StorePromotionDecorator
    def self.prepended(base)
      base.class_eval do
        validate :store_matches_promotion
      end
    end

    private

    def store_matches_promotion
      return if promotion.nil? || promotion.store_id.nil? || store_id == promotion.store_id

      errors.add(:store, 'must be the promotion store')
    end
  end
end

Spree::StorePromotion.prepend(SpreeTenants::StorePromotionDecorator)
