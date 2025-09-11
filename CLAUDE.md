# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Testing
```bash
bundle exec rspec                   # Run all tests
bundle exec rspec spec/models       # Run model tests
bundle exec rspec spec/features     # Run feature tests
```

### Development Setup
```bash
bundle install                      # Install dependencies
bundle exec rake test_app          # Generate dummy app for testing
```

### Building and Releasing
```bash
bundle exec gem bump -p -t         # Bump version and tag
bundle exec gem release            # Release gem to RubyGems
```

## Architecture

This is a Spree Commerce extension that adds multi-tenancy support using the acts_as_tenant gem. The extension automatically scopes Spree models with store_id columns to the current store (tenant).

### Key Components

1. **Engine (lib/spree_tenants/engine.rb)**: Core engine that applies acts_as_tenant to all Spree models with store_id columns. Uses a prepend pattern to dynamically add tenant scoping after Rails initialization.

2. **Controller Decorators**: 
   - `app/controllers/spree/application_controller_decorator.rb`: Sets current tenant based on current_store
   - `app/controllers/spree/admin/base_controller_decorator.rb`: Admin-specific tenant handling
   - `app/controllers/spree/api/base_controller_decorator.rb`: API-specific tenant handling

3. **Model Decorators**: Located in `app/models/spree_tenants/`, these add tenant-specific behavior to Spree models like Product, Variant, Store, etc.

4. **Migrations**: Database migrations in `db/migrate/` add store_id columns and unique indexes to ensure data integrity within tenant scope.

### Tenant Scoping Behavior

- Models with store_id are automatically scoped to ActsAsTenant.current_tenant
- New records automatically get assigned current store_id
- Queries are automatically filtered by current store
- Can be bypassed using `ActsAsTenant.without_tenant` or `ActsAsTenant.with_tenant(store)`

### Testing Approach

Tests use RSpec with a dummy Spree app generated in spec/dummy/. Test helpers in spec/support/ provide utilities for multi-tenant testing scenarios.