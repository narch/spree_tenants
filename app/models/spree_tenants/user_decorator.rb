module SpreeTenants
  # Devise and Spree::LegacyUser validate email uniqueness globally; users are
  # unique per store.
  module UserDecorator
    def self.apply!(klass)
      return unless klass.table_exists? && klass.column_names.include?('store_id')

      klass.class_eval do
        include SpreeTenants::CrossTenantValidation
        validates_uniqueness_scoped_to_store :email, allow_blank: true
      end
    end

    def self.user_classes
      [Spree.user_class(constantize: false), Spree.admin_user_class(constantize: false)]
        .compact.uniq.filter_map(&:safe_constantize)
    end
  end
end

SpreeTenants::UserDecorator.user_classes.each { |klass| SpreeTenants::UserDecorator.apply!(klass) }
