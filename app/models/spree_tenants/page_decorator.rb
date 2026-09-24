module SpreeTenants
  module PageDecorator
    def self.prepended(base)
      base.class_eval do
        # Pages belong to a Store or a Theme; derive the store from either.
        before_validation :inherit_store_id_from_pageable
        validate :pageable_belongs_to_same_store

        private

        def pageable_store_id
          case pageable
          when Spree::Store then pageable.id
          when nil then nil
          else pageable.try(:store_id)
          end
        end

        def inherit_store_id_from_pageable
          self.store_id = pageable_store_id if store_id.blank?
        end

        def pageable_belongs_to_same_store
          owner = pageable_store_id
          return if store_id.blank? || owner.blank?

          errors.add(:pageable, 'must belong to the same store') if owner != store_id
        end
      end
    end
  end
end

Spree::Page.prepend(SpreeTenants::PageDecorator)
