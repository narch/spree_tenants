pin 'application-spree-tenants', to: 'spree_tenants/application.js', preload: false

pin_all_from SpreeTenants::Engine.root.join('app/javascript/spree_tenants/controllers'),
             under: 'spree_tenants/controllers',
             to:    'spree_tenants/controllers',
             preload: 'application-spree-tenants'
