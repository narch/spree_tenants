module SpreeTenants
  # Mail without an order is branded and linked for the tenant, and the mail
  # host is set per message instead of on ActionMailer::Base.
  module BaseMailerDecorator
    def current_store
      @current_store ||= @order&.store.presence || ActsAsTenant.current_tenant || super
    end

    def default_url_options
      host = @tenant_mail_host.presence || current_store.try(:url_or_custom_domain)
      host.present? ? super.merge(host: host) : super
    end

    private

    def ensure_default_action_mailer_url_host(store_url = nil)
      @tenant_mail_host = store_url.presence || current_store.try(:url_or_custom_domain)
    end
  end
end

Spree::BaseMailer.prepend(SpreeTenants::BaseMailerDecorator)
