module SpreeTenants
  # Makes store_id authoritative for resources Spree models as many-to-many
  # (products, promotions) and mirrors the join rows from it.
  module DirectStoreOwnership
    extend ActiveSupport::Concern

    class_methods do
      # @param through [Symbol] the join association, e.g. :store_products
      def owned_directly_by_store(through:)
        @store_join_association = through

        scope :for_store, ->(store) { where(store_id: store.id) }

        after_save :sync_store_join_rows, if: :saved_change_to_store_id?
        validate :requested_store_ids_match_owner
        after_save { @requested_store_ids = nil }
      end

      def store_join_association
        @store_join_association || superclass.try(:store_join_association)
      end
    end

    # Spree::MultiStoreResource hook.
    def disable_store_presence_validation?
      true
    end

    # The admin store checkboxes cannot change ownership; a write naming
    # another store fails validation.
    def store_ids
      owner = store_id || ActsAsTenant.current_tenant&.id
      owner ? [owner] : []
    end

    def store_ids=(ids)
      @requested_store_ids = Array(ids).map(&:to_i).reject(&:zero?).uniq
    end

    private

    def requested_store_ids_match_owner
      return if @requested_store_ids.nil? || @requested_store_ids.empty?
      return if @requested_store_ids == store_ids

      errors.add(:stores, "cannot be changed: this #{model_name.human.downcase} belongs to exactly one store")
    end

    def sync_store_join_rows
      return if store_id.blank?

      join_rows = public_send(self.class.store_join_association)
      join_rows.where.not(store_id: store_id).destroy_all
      join_rows.find_or_create_by!(store_id: store_id)
      association(:stores).reset
    end
  end
end
