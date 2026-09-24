require 'acts_as_tenant'

module SpreeTenants
  # Loads the decorators and applies acts_as_tenant to every Spree base model
  # with a store_id column. Idempotent and safe to re-run on reload.
  module TenantScoping
    # Models with a store_id column that are intentionally not tenant-scoped.
    # PaymentMethod keeps Spree's join-table ownership; the Store* join models
    # are derived from Product/Promotion store_id.
    GLOBAL_MODELS = %w[
      Spree::Store
      Spree::Country
      Spree::State
      Spree::PaymentMethod
      Spree::StorePaymentMethod
      Spree::StoreProduct
      Spree::StorePromotion
    ].freeze

    class NotApplied < StandardError; end

    class << self
      # No-op (with a warning) until the database and Spree are ready, e.g.
      # during app generation or db:create.
      def activate!
        unless ready?
          Rails.logger.warn '[spree_tenants] skipped activation: database or Spree configuration not ready'
          return false
        end

        load_decorators
        apply!
      end

      def apply!
        candidate_models.each { |model| apply_to(model) }
        @applied = true
      end

      def applied?
        @applied == true
      end

      # Request-time safety net: never serve unscoped data.
      def ensure_applied!
        return true if applied?

        activate! or raise NotApplied, 'spree_tenants could not apply tenant scoping; refusing to serve unscoped data'
      end

      def candidate_models
        spree_models.select { |model| tenant_owned?(model) }
      end

      def scoped_models
        spree_models.select { |model| model.respond_to?(:scoped_by_tenant?) }
      end

      # Anything here that is not in GLOBAL_MODELS is a configuration bug.
      def unscoped_models_with_store_id
        spree_models.select do |model|
          has_store_id?(model) && !model.respond_to?(:scoped_by_tenant?)
        end
      end

      def global?(model)
        GLOBAL_MODELS.any? do |name|
          klass = name.safe_constantize
          klass && model <= klass
        end
      end

      def apply_to(model)
        return if model.respond_to?(:scoped_by_tenant?)

        model.acts_as_tenant :store, foreign_key: 'store_id', class_name: 'Spree::Store'
        Rails.logger.debug { "[spree_tenants] applied acts_as_tenant to #{model.name}" }
      end

      def ready?
        return false if Spree.user_class(constantize: false).blank?

        connection = ActiveRecord::Base.connection
        connection.data_source_exists?('spree_stores') && connection.column_exists?('spree_products', 'store_id')
      rescue ActiveRecord::ActiveRecordError
        false
      end

      # The configured customer and staff classes, whatever their namespace.
      def user_classes
        [Spree.user_class(constantize: false), Spree.admin_user_class(constantize: false)]
          .compact.uniq.filter_map(&:safe_constantize)
          .select { |klass| klass < ActiveRecord::Base }
          .map(&:base_class)
      end

      private

      # Through Zeitwerk, so files load once per (re)load and constants are
      # never redefined.
      def load_decorators
        loader = Rails.autoloaders.main
        Dir.glob(SpreeTenants::Engine.root.join('app/*')).each do |dir|
          loader.eager_load_dir(dir) if loader.dirs.include?(dir)
        end
      end

      def spree_models
        Rails.application.eager_load! unless Rails.application.config.eager_load

        models = ActiveRecord::Base.descendants.select do |model|
          model.name&.start_with?('Spree::') && !model.abstract_class? && model.base_class == model
        end
        (models + user_classes).uniq
      end

      def tenant_owned?(model)
        !global?(model) && has_store_id?(model)
      end

      def has_store_id?(model)
        model.table_exists? && model.column_names.include?('store_id')
      end
    end
  end
end
