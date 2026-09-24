# Spree Tenants

A multi-tenancy extension for [Spree Commerce](https://spreecommerce.org) that provides store-level data isolation using the battle-tested [acts_as_tenant](https://github.com/ErwinM/acts_as_tenant) gem.

## Features

- **Automatic tenant scoping** - All Spree models with `store_id` are automatically scoped to the current store
- **Data isolation** - Each store's data is isolated from other stores
- **Thread-safe** - Uses thread-local storage for current tenant
- **Flexible** - Can be bypassed when needed for admin operations
- **Battle-tested** - Built on top of acts_as_tenant with 5M+ downloads

## Installation

1. Add this extension to your Gemfile with this line:

    ```ruby
    bundle add spree_tenants
    ```

2. Run the install generator

    ```ruby
    bundle exec rails g spree_tenants:install
    ```

3. Restart your server

  If your server was running, restart it so that it can find the assets properly.

## How it Works

This extension uses `acts_as_tenant` to automatically scope all Spree models that have a `store_id` column to the current store. This happens transparently:

### In Controllers

The current tenant is automatically set based on the current store (determined by domain/subdomain):

```ruby
# Automatically scoped to current store
@products = Spree::Product.all  # Only returns products for the current store
```

### Creating Records

New records are automatically assigned to the current store:

```ruby
# store_id is set automatically
product = Spree::Product.create(name: 'New Product')
product.store_id # => current_store.id
```

### Admin Operations

For admin operations that need to access all stores:

```ruby
# Bypass tenant scoping
ActsAsTenant.without_tenant do
  all_products = Spree::Product.all # Returns products from all stores
end

# Or work with a specific store
ActsAsTenant.with_tenant(specific_store) do
  store_products = Spree::Product.all # Products for specific_store
end
```

### Which models are scoped

Every concrete `Spree::*` base model whose table has a `store_id` column is scoped
automatically (`SpreeTenants::TenantScoping`). STI subclasses inherit scoping from
their base class. A short, explicit list of models is intentionally global
(`SpreeTenants::TenantScoping::GLOBAL_MODELS`):

- `Spree::Store` (the tenant), `Spree::Country`, `Spree::State`
- `Spree::PaymentMethod` (see below)
- the `Spree::StoreProduct`, `Spree::StorePromotion` and `Spree::StorePaymentMethod` join models

Run `bundle exec rails spree_tenants:verify` in a host app to print the scoped
models and fail if any model with a `store_id` column is unscoped by accident.

### Ownership model

Spree natively lets products, promotions and payment methods belong to several
stores through join tables. This extension resolves that as follows:

- **Products and promotions** belong to exactly one store through `store_id`.
  The Spree join rows (`spree_products_stores`, `spree_promotions_stores`) are
  mirrored from `store_id` after every save, so Spree's own associations,
  `for_store` scopes and promotion handlers keep working.
- Because a product or promotion has exactly one store, the admin's store
  checkboxes on those forms cannot change ownership (a write to `store_ids`
  naming another store fails validation), and the "Import products from store"
  option on the new-store form is refused with a validation error. Importing
  payment methods still works.
- **Payment methods** keep Spree's native ownership through
  `spree_payment_methods_stores` and are **not** tenant-scoped, so one gateway
  configuration can be shared by several stores. Assign stores to a payment
  method in the admin. The legacy `store_id` column on `spree_payment_methods`
  is unused and nullable.

### Requests and jobs

A Rack middleware (`SpreeTenants::CurrentStoreMiddleware`) sets the tenant for
every request from the request host, using Spree's own current-store finder.
That covers Devise sign-in, registration and password controllers and any
host-application controller, not only Spree's. Controller decorators on
`Spree::BaseController` (storefront and admin) and `Spree::Api::V2::BaseController`
(API) additionally pin the tenant to `current_store` before any other callback,
including admin authorization. The tenant is cleared when the request finishes.
acts_as_tenant serializes the tenant into ActiveJob payloads, so background jobs
enqueued during a request run in the same store. Webhook delivery is filtered
to the subscribers of the record's store even outside a tenant context.

Spree's own notion of the current store follows the tenant: `Spree::Store.current`
and `Spree::Current.store` return the tenant whenever one is set (Spree would
otherwise answer with the default store from model code such as variant stock
items, role assignments, invitations, integrations and mailers). Mail without an
order is branded and linked for the tenant store, without mutating the global
ActionMailer host.

Requests on a host that matches no store fall back to Spree's default store, as
in stock Spree. If no store is flagged default, no tenant is set and Spree
responds with 404.

### Users

Customers (`Spree.user_class`) and admin users (`Spree.admin_user_class`) belong
to a store, and email uniqueness is per store. Stores never share staff: an
admin account exists in exactly one store and cannot be assigned to another
(`Store#add_user` refuses users from other stores, which is what Spree's admin
attempts when it copies staff into a newly created store). `Store#users` keeps
Spree's meaning (staff assigned through role users); customers are available as
`Store#customer_users`. Roles and staff invitations are per store too, and the
admin's store switcher and store checkboxes only ever list the store being
served.

When a store is created in the admin, the person creating it gets a separate
admin account in the new store with the same email and password, so the
redirect to the new store's admin lands somewhere they can sign in. Nothing
links the two accounts afterwards. For any other case, create the first
administrator of a new store with:

```bash
bundle exec rails "spree_tenants:create_admin[store-code,admin@example.com,password]"
```

### Creating stores

Every new store, whether created in the admin, the console or by the
`spree_tenants:create_store` task, is provisioned inside the same transaction
with the records a tenant needs: roles, shipping categories, a default stock
location, the Default and Non-taxable tax categories, a zone for its country,
the Digital Delivery shipping method, store credit categories and the shared
Store Credit payment method, refund and return reasons, reimbursement types and
the standard taxonomies. Set `SpreeTenants::Config.provision_new_stores = false`
to opt out and provision manually with the rake tasks.

Zones are per store, so a new store starts with a single zone for its default
country rather than the continent zones Spree seeds once globally. Add further
zones, shipping methods, tax rates and payment methods in the admin.

### Same-store validations

Records that link two tenant-owned rows (classifications, product properties,
line items, shipments, stock items, option value variants, ...) inherit their
`store_id` from a parent and validate that every parent belongs to the same
store. A foreign key alone would only prove the parent exists.

## Migration

The extension includes migrations that add `store_id` columns to all relevant Spree tables and sets up proper indexes for performance.

After upgrading, install and run the new engine migrations in each host app:

```bash
bundle exec rake railties:install:migrations FROM=spree_tenants
bundle exec rails db:migrate
```

`ReconcileStoreOwnership` does the following. Take a database backup first, and
run it **before** creating the second store or its admin user.

- Removes the `default: 1` on `store_id` for pages, page sections, blocks and
  links, refund reasons, reimbursement types, return authorization reasons,
  store credit categories and types, webhook events and subscribers, promotion
  categories, stock transfers and digitals. Records created without tenant
  context now fail instead of silently landing in store 1.
- Drops the global unique name indexes on refund reasons, reimbursement types
  and return authorization reasons.
- Makes `spree_payment_methods.store_id` nullable and mirrors existing values
  into `spree_payment_methods_stores`.
- Backfills `spree_products_stores` and `spree_promotions_stores` from
  `store_id` and deletes join rows that disagree with it.
- Adds per-store, case-insensitive unique indexes: on `name` for zones, tax
  categories, stock locations, shipping categories, roles, properties, option
  types, refund reasons, reimbursement types, return authorization reasons,
  store credit categories and types and promotion categories (live rows only
  where the table is soft-deletable); on `email` for customers and admin users
  (blank excluded), replacing the global email indexes; and on `sku` for
  variants (blank and soft-deleted excluded).
- Removes the duplicate legacy indexes an earlier migration left on users,
  roles and products.
- Adds `store_id` to `spree_invitations` (backfilled from the invited store)
  and unique indexes on the product and promotion join tables.

The case-insensitive indexes fail if a store already holds two rows differing
only by case. Check each table before migrating, for example:

```sql
SELECT store_id, lower(name), count(*) FROM spree_zones GROUP BY 1, 2 HAVING count(*) > 1;
SELECT store_id, lower(email), count(*) FROM spree_users WHERE email <> '' GROUP BY 1, 2 HAVING count(*) > 1;
SELECT store_id, lower(sku), count(*) FROM spree_variants WHERE deleted_at IS NULL AND sku <> '' GROUP BY 1, 2 HAVING count(*) > 1;
```

The migration runs the same duplicate check itself before any schema change
and aborts listing every offender, so nothing is left half-applied. It runs in
one transaction and takes write locks on the indexed tables for its duration;
run it in a maintenance window.

The migration supports PostgreSQL and SQLite and refuses MySQL, which lacks
partial indexes.

Mail branding and links depend on Devise mailers inheriting from
`Spree::BaseMailer` (`config.parent_mailer = 'Spree::BaseMailer'` in the host's
Devise initializer). Keep that setting.

In development, model discovery eager-loads the application on every code
reload so that no model with a `store_id` column can be missed. That is the
cost of an allowlist-free design; it does not affect production.

### Failing closed

`config/initializers/acts_as_tenant.rb` leaves `require_tenant` off so console
sessions, rake tasks and seeding can work across stores. Every Spree request and
every job enqueued from one runs with a tenant. Host-app controllers that do not
inherit from `Spree::BaseController`, recurring jobs and one-off scripts do not.
Once those are audited and wrapped in `ActsAsTenant.with_tenant(store)` or
`ActsAsTenant.without_tenant`, set this in a host-app initializer so an unscoped
query raises `ActsAsTenant::Errors::NoTenantSet` instead of returning every
store's records:

```ruby
ActsAsTenant.configure { |config| config.require_tenant = true }
```

## Seeding Data

This extension provides rake tasks to seed tenant-specific data for your stores.

### Available Rake Tasks

```bash
# Seed global data (countries, states) - run once per environment
bundle exec rails spree_tenants:seed_global

# Seed all existing stores with basic data
bundle exec rails spree_tenants:seed_all_stores

# Seed a specific store by ID
bundle exec rails "spree_tenants:seed_store[1]"

# Seed a specific store by code
bundle exec rails "spree_tenants:seed_store_by_code[my-store]"

# Create a new store and seed it with basic data (atomic: a failure rolls the store back)
bundle exec rails "spree_tenants:create_store[Store Name,store-code,store.example.com]"

# Report which models are tenant-scoped; exits 1 if a store_id model is unscoped by accident
bundle exec rails spree_tenants:verify
```

### What Gets Seeded

For **global data** (shared across all stores):
- Countries (using Spree's seed data)
- States/provinces (using Spree's seed data)

For **each store**:
- Roles (admin, user)
- Shipping categories (Default, Digital) and the Digital Delivery shipping method
- A default stock location
- Tax categories (Default, Non-taxable)
- A zone for the store's default country
- Store credit categories, and the shared Store Credit payment method assigned to the store
- Refund reasons, return authorization reasons and reimbursement types (the same set Spree seeds)
- The Categories, Brands and Collections taxonomies

Seeding is idempotent: re-running it for a store creates nothing twice.

### Production Usage

**Recommended workflow for production:**

```bash
# 1. First deployment - seed global data once
RAILS_ENV=production bundle exec rails spree_tenants:seed_global

# 2. Create your first store with data
RAILS_ENV=production bundle exec rails "spree_tenants:create_store[My Store,my-store,mystore.com]"

# 3. For additional stores
RAILS_ENV=production bundle exec rails "spree_tenants:create_store[Another Store,another-store,another.com]"

# 4. Or seed existing stores individually
RAILS_ENV=production bundle exec rails "spree_tenants:seed_store_by_code[existing-store]"
```

**Note:** Payment methods are not seeded. They keep Spree's native multi-store ownership, so configure each one in the admin and tick the stores it should be available in.

## Developing

1. Create a dummy app

    ```bash
    bundle update
    bundle exec rake test_app
    ```

2. Add your new code
3. Run tests

    ```bash
    bundle exec rspec
    ```

When testing your applications integration with this extension you may use it's factories.
Simply add this require statement to your spec_helper:

```ruby
require 'spree_tenants/factories'
```

## Releasing a new version

```shell
bundle exec gem bump -p -t
bundle exec gem release
```

For more options please see [gem-release README](https://github.com/svenfuchs/gem-release)

## Contributing

If you'd like to contribute, please take a look at the
[instructions](CONTRIBUTING.md) for installing dependencies and crafting a good
pull request.
