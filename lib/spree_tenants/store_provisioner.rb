module SpreeTenants
  # Creates the per-store records a tenant needs. Idempotent. Runs from
  # Store#after_create, the rake tasks and SpreeTenants::Seeds.
  class StoreProvisioner
    ROLE_NAMES = %w[admin user].freeze
    STORE_CREDIT_CATEGORIES = ['Default', 'Non-expiring', 'Expiring'].freeze
    RETURN_AUTHORIZATION_REASONS = [
      'Better price available',
      'Missed estimated delivery date',
      'Missing parts or accessories',
      'Damaged/Defective',
      'Different from what was ordered',
      'Different from description',
      'No longer needed/wanted',
      'Accidental order',
      'Unauthorized purchase'
    ].freeze
    REIMBURSEMENT_TYPES = {
      'Store Credit' => 'Spree::ReimbursementType::StoreCredit',
      'Exchange' => 'Spree::ReimbursementType::Exchange',
      'Original payment' => 'Spree::ReimbursementType::OriginalPayment'
    }.freeze
    TAXONOMIES = %w[Categories Brands Collections].freeze

    def self.call(store, logger: nil)
      new(store, logger: logger).call
    end

    # Creates (or finds) an admin user in the store with the store's admin role.
    def self.create_admin!(store, email:, password:)
      ActsAsTenant.with_tenant(store) do
        admin_class = Spree.admin_user_class
        admin = admin_class.find_by(email: email) || admin_class.new(email: email)
        if admin.new_record?
          admin.password = password
          admin.password_confirmation = password if admin.respond_to?(:password_confirmation=)
          admin.save!
        end

        store.add_user(admin, Spree::Role.find_or_create_by!(name: 'admin', store_id: store.id))
        admin
      end
    end

    # Gives the store its own admin account for an admin of another store
    # (same email and password hash, separate record, this store's admin role).
    def self.bootstrap_admin_from!(store, source_admin)
      ActsAsTenant.with_tenant(store) do
        admin_class = Spree.admin_user_class
        admin = admin_class.find_by(email: source_admin.email)

        unless admin
          admin = admin_class.new(email: source_admin.email)
          %w[encrypted_password first_name last_name].each do |attribute|
            next unless admin.has_attribute?(attribute) && source_admin.has_attribute?(attribute)

            admin[attribute] = source_admin[attribute]
          end
          admin.save!(validate: false) # Devise wants a plaintext password on create
        end

        store.add_user(admin, Spree::Role.find_or_create_by!(name: 'admin', store_id: store.id))
        admin
      end
    end

    def initialize(store, logger: nil)
      @store = store
      @logger = logger
    end

    def call
      ActsAsTenant.with_tenant(store) do
        log "Provisioning store: #{store.name} (#{store.code})"
        create_roles
        create_shipping_categories
        create_stock_location
        create_tax_categories
        create_zone
        create_digital_delivery
        create_store_credit_categories
        create_store_credit_payment_method
        create_returns_environment
        create_taxonomies
        log "Provisioned store: #{store.name}"
      end
      store
    end

    private

    attr_reader :store

    def log(message)
      @logger&.call(message)
    end

    def create_roles
      ROLE_NAMES.each { |name| Spree::Role.find_or_create_by!(name: name, store_id: store.id) }
    end

    def create_shipping_categories
      Spree::ShippingCategory.find_or_create_by!(name: 'Default', store_id: store.id)
      Spree::ShippingCategory.find_or_create_by!(name: 'Digital', store_id: store.id)
    end

    def create_stock_location
      return if Spree::StockLocation.where(store_id: store.id, default: true).exists?

      Spree::StockLocation.create!(
        name: Spree.t(:default_stock_location_name),
        store_id: store.id,
        default: true,
        active: true,
        propagate_all_variants: false,
        country: store.default_country,
        state: store.default_country&.states&.first
      )
    end

    def create_tax_categories
      Spree::TaxCategory.find_or_create_by!(name: 'Default', store_id: store.id) do |tax_category|
        tax_category.is_default = true
        tax_category.description = 'Default tax category'
      end
      Spree::TaxCategory.find_or_create_by!(name: 'Non-taxable', store_id: store.id)
    end

    def create_digital_delivery
      digital_category = Spree::ShippingCategory.find_or_create_by!(name: 'Digital', store_id: store.id)
      method = Spree::ShippingMethod.find_or_initialize_by(name: Spree.t('digital.digital_delivery'), store_id: store.id)
      method.display_on = 'both'
      method.shipping_categories = [digital_category]
      method.calculator ||= Spree::Calculator::Shipping::DigitalDelivery.new
      method.zones = Spree::Zone.where(store_id: store.id)
      method.save!
    end

    # The Store Credit payment method is shared (native Spree ownership);
    # this store is added to it.
    def create_store_credit_payment_method
      ActsAsTenant.without_tenant do
        payment_method = Spree::PaymentMethod::StoreCredit.find_or_initialize_by(name: Spree.t(:store_credit_name))
        payment_method.description ||= Spree.t(:store_credit_name)
        payment_method.active = true if payment_method.new_record?
        payment_method.stores << store unless payment_method.stores.include?(store)
        payment_method.save!
      end
    end

    def create_zone
      country = store.default_country
      return unless country

      zone = Spree::Zone.find_or_create_by!(name: country.name, kind: 'country', store_id: store.id)
      zone.zone_members.find_or_create_by!(zoneable: country)
    end

    def create_store_credit_categories
      STORE_CREDIT_CATEGORIES.each do |name|
        Spree::StoreCreditCategory.find_or_create_by!(name: name, store_id: store.id)
      end
    end

    def create_returns_environment
      Spree::RefundReason.find_or_create_by!(name: 'Return processing', store_id: store.id) do |reason|
        reason.mutable = false
      end

      RETURN_AUTHORIZATION_REASONS.each do |name|
        Spree::ReturnAuthorizationReason.find_or_create_by!(name: name, store_id: store.id)
      end

      REIMBURSEMENT_TYPES.each do |name, type|
        Spree::ReimbursementType.find_or_create_by!(name: name, type: type, store_id: store.id)
      end
    end

    def create_taxonomies
      TAXONOMIES.each { |name| Spree::Taxonomy.find_or_create_by!(name: name, store_id: store.id) }
    end
  end
end
