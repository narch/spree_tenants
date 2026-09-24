module SpreeTenants
  module StoreIdInheritance
    extend ActiveSupport::Concern

    class_methods do
      # Inherit store_id from the first listed association that has one and
      # validate that all of them belong to the same store.
      def inherit_store_id_from(*associations)
        before_validation :inherit_store_id
        validate :associations_belong_to_same_store

        define_method :inherit_store_id do
          return if store_id.present?

          associations.each do |association|
            next unless respond_to?(association)

            associated_record = send(association)
            if associated_record.respond_to?(:store_id) && associated_record.store_id.present?
              self.store_id = associated_record.store_id
              break
            end
          end
        end

        define_method :associations_belong_to_same_store do
          return if store_id.blank?

          associations.each do |association|
            next unless respond_to?(association)

            associated_record = send(association)
            next unless associated_record.respond_to?(:store_id) && associated_record.store_id.present?

            errors.add(association, 'must belong to the same store') if associated_record.store_id != store_id
          end
        end

        private :inherit_store_id, :associations_belong_to_same_store
      end
    end
  end
end
