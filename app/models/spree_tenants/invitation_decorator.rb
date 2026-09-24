module SpreeTenants
  # Staff invitations are per store.
  module InvitationDecorator
    def self.prepended(base)
      base.class_eval do
        before_validation :inherit_store_id_from_resource
        validate :resource_belongs_to_same_store
      end
    end

    private

    # Store#add_user returns nil for a user from another store; do not accept
    # an invitation with no role.
    def create_role_user
      return if invitee.blank?

      role_user = resource.add_user(invitee, role)
      raise ActiveRecord::RecordNotSaved.new('invitee does not belong to the invited store', self) if role_user.nil?

      self.role_user = role_user
      save!
    end

    def inherit_store_id_from_resource
      self.store_id = resource.id if store_id.blank? && resource.is_a?(Spree::Store)
    end

    def resource_belongs_to_same_store
      return unless resource.is_a?(Spree::Store) && store_id.present?

      errors.add(:resource, 'must belong to the same store') if resource.id != store_id
    end
  end
end

Spree::Invitation.prepend(SpreeTenants::InvitationDecorator) if defined?(Spree::Invitation) && Spree::Invitation.column_names.include?('store_id')
