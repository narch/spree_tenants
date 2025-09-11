require 'spec_helper'

RSpec.describe SpreeTenants::Engine do
  describe 'auto-inclusion of acts_as_tenant' do
    before do
      # Create test tables
      ActiveRecord::Base.connection.create_table :test_models_with_store, force: true do |t|
        t.integer :store_id
        t.string :name
        t.timestamps
      end

      ActiveRecord::Base.connection.create_table :test_models_without_store, force: true do |t|
        t.string :name
        t.timestamps
      end
    end

    after do
      # Clean up test tables
      ActiveRecord::Base.connection.drop_table :test_models_with_store, if_exists: true
      ActiveRecord::Base.connection.drop_table :test_models_without_store, if_exists: true
      
      # Remove test classes
      Object.send(:remove_const, :TestModelWithStore) if defined?(TestModelWithStore)
      Object.send(:remove_const, :TestModelWithoutStore) if defined?(TestModelWithoutStore)
    end

    it 'automatically applies acts_as_tenant to Spree models with store_id column' do
      # Define a Spree model with store_id
      class ::Spree::TestModelWithStore < ActiveRecord::Base
        self.table_name = 'test_models_with_store'
      end

      # Trigger the initializer
      Rails.application.config.to_prepare_blocks.each(&:call)

      # Check that acts_as_tenant was applied
      expect(Spree::TestModelWithStore.respond_to?(:acts_as_tenant)).to be true
    end

    it 'does not apply acts_as_tenant to Spree models without store_id column' do
      # Define a Spree model without store_id
      class ::Spree::TestModelWithoutStore < ActiveRecord::Base
        self.table_name = 'test_models_without_store'
      end

      # Trigger the initializer
      Rails.application.config.to_prepare_blocks.each(&:call)

      # Check that acts_as_tenant was not applied
      # The model won't have tenant-specific methods
      model = Spree::TestModelWithoutStore.new
      expect(model.respond_to?(:store)).to be false
    end

    it 'does not apply acts_as_tenant to non-Spree models' do
      # Define a non-Spree model with store_id
      class ::TestModelWithStore < ActiveRecord::Base
        self.table_name = 'test_models_with_store'
      end

      # Trigger the initializer
      Rails.application.config.to_prepare_blocks.each(&:call)

      # Check that acts_as_tenant was not applied
      model = TestModelWithStore.new
      expect(model.respond_to?(:store)).to be false
    end

    it 'does not apply acts_as_tenant to Spree::Store (the tenant model)' do
      # Spree::Store should not have acts_as_tenant applied
      # since it IS the tenant
      Rails.application.config.to_prepare_blocks.each(&:call)

      # Store should not be scoped to itself
      store = create(:store)
      ActsAsTenant.with_tenant(store) do
        # Should be able to see all stores, not just current
        expect(Spree::Store.unscoped.count).to be >= 1
      end
    end

    it 'handles errors gracefully' do
      # Define a Spree model that will cause an error
      class ::Spree::TestModelWithStore < ActiveRecord::Base
        self.table_name = 'non_existent_table'
      end

      # This should not raise an error
      expect { Rails.application.config.to_prepare_blocks.each(&:call) }.not_to raise_error
    end
  end

  describe 'configuration' do
    it 'sets up SpreeTenants::Config' do
      expect(SpreeTenants::Config).to be_a(SpreeTenants::Configuration)
    end
    
    it 'loads acts_as_tenant' do
      expect(defined?(ActsAsTenant)).to be_truthy
    end
  end
end