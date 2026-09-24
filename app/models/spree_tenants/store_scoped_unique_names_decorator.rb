module SpreeTenants
  # Spree validates these names globally; every store seeds the same ones.
  module StoreScopedUniqueNamesDecorator
    MODELS = %w[
      Spree::Zone
      Spree::ReimbursementType
      Spree::RefundReason
      Spree::ReturnAuthorizationReason
      Spree::StoreCreditCategory
      Spree::StoreCreditType
      Spree::PromotionCategory
    ].freeze

    def self.apply!
      MODELS.each do |class_name|
        klass = class_name.safe_constantize
        next unless klass && klass.table_exists? && klass.column_names.include?('store_id')

        klass.class_eval do
          include SpreeTenants::CrossTenantValidation
          validates_uniqueness_scoped_to_store :name
        end
      end
    end
  end
end

SpreeTenants::StoreScopedUniqueNamesDecorator.apply! if SpreeTenants::TenantScoping.ready?
