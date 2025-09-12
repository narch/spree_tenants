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

## Migration

The extension includes migrations that add `store_id` columns to all relevant Spree tables and sets up proper indexes for performance.

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

# Create a new store and seed it with basic data
bundle exec rails "spree_tenants:create_store[Store Name,store-code,store.example.com]"
```

### What Gets Seeded

For **global data** (shared across all stores):
- Countries (using Spree's seed data)
- States/provinces (using Spree's seed data)

For **each store**:
- Roles (if store-scoped)
- Shipping categories (Default, Digital)
- Stock locations with proper addresses
- Tax categories (Default)
- Geographic zones based on store's country
- Store credit categories
- Reimbursement types
- Return reasons
- Basic product taxonomies and taxons

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

**Note:** Payment methods are not automatically seeded as they are complex and store-specific. Configure them manually through the admin interface based on each store's requirements.

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
