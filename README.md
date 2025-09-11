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
