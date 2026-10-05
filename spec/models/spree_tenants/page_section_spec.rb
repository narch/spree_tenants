require 'spec_helper'

RSpec.describe 'Nil-safe delegated stores', type: :model do
  include_context 'multi_tenant_setup'

  let(:controller_class) do
    Class.new(ActionController::Base) do
      include Spree::Core::ControllerHelpers::Store
      attr_accessor :current_store
    end
  end

  [Spree::PageSection, Spree::PageBlock, Spree::Shipment].each do |model_class|
    it "allows the admin to set #{model_class.name}'s store before assigning its parent" do
      record = ActsAsTenant.with_tenant(store) { model_class.new }
      controller = controller_class.new
      controller.current_store = store

      expect { controller.send(:ensure_current_store, record) }.not_to raise_error
      expect(record.store).to eq(store)
      expect(record.store_id).to eq(store.id)
    end
  end
end
