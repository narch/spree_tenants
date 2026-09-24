require 'spec_helper'

RSpec.describe 'Final review fixes', type: :model do
  include_context 'multi_tenant_setup'

  describe 'payment methods in Spree admin/API create and update' do
    let(:controller_class) do
      Class.new(ActionController::Base) do
        include Spree::Core::ControllerHelpers::Store
        attr_accessor :current_store
      end
    end

    it 'ignores the legacy store_id column so Spree attaches the current store through the join table' do
      payment_method = Spree::PaymentMethod::Check.new(name: 'Card')
      expect(payment_method.has_attribute?(:store_id)).to be false

      controller = controller_class.new
      controller.current_store = another_store
      expect { controller.send(:ensure_current_store, payment_method) }.not_to raise_error
      expect(payment_method.stores).to include(another_store)
    end
  end

  describe 'creating a store from the admin' do
    it 'bootstraps a separate admin account for the creator in the new store' do
      creator = ActsAsTenant.with_tenant(store) { create(:admin_user, email: 'boss@example.com') }
      new_store = create(:store, name: 'Store 3', code: 'store3')

      admin = SpreeTenants::StoreProvisioner.bootstrap_admin_from!(new_store, creator)

      expect(admin).not_to eq(creator)
      expect(admin.store_id).to eq(new_store.id)
      expect(admin.email).to eq('boss@example.com')
      ActsAsTenant.with_tenant(new_store) do
        expect(new_store.users).to include(admin)
        expect(admin.spree_admin?(new_store)).to be true
      end
      expect(ActsAsTenant.with_tenant(store) { store.users }).not_to include(admin)
    end

    it 'runs from the admin controller after Spree refused the staff copy' do
      expect(Spree::Admin::StoresController.ancestors).to include(Spree::Admin::StoresControllerDecorator)
    end
  end

  describe 'invitations' do
    it 'fail loudly instead of accepting with no role when the invitee is from another store' do
      inviter = ActsAsTenant.with_tenant(store) { create(:admin_user) }
      invitation = ActsAsTenant.with_tenant(store) { Spree::Invitation.create!(email: 'x@example.com', inviter: inviter) }
      foreign = ActsAsTenant.with_tenant(another_store) { create(:admin_user, email: 'x@example.com') }

      expect do
        ActsAsTenant.with_tenant(store) do
          invitation.invitee = foreign
          invitation.send(:create_role_user)
        end
      end.to raise_error(ActiveRecord::RecordNotSaved)
    end
  end

  describe 'middleware' do
    before do
      ActsAsTenant.without_tenant do
        store.update!(url: 'store1.example.com')
        another_store.update!(url: 'store2.example.com')
      end
    end

    it 'keeps the tenant until the response body is closed (streamed responses)' do
      streamed = Class.new do
        def each
          yield ActsAsTenant.current_tenant&.id.to_s
        end
      end
      app = ->(_env) { [200, {}, streamed.new] }

      _status, _headers, body = SpreeTenants::CurrentStoreMiddleware.new(app).call(Rack::MockRequest.env_for('http://store2.example.com/'))
      chunks = []
      body.each { |chunk| chunks << chunk }
      body.close

      expect(chunks).to eq([another_store.id.to_s])
      expect(ActsAsTenant.current_tenant).to be_nil
    end

    it 'stashes the resolved store in the Rack env for the controllers' do
      seen = nil
      app = ->(env) { seen = env[SpreeTenants::CurrentStoreMiddleware::ENV_KEY]; [200, {}, []] }

      SpreeTenants::CurrentStoreMiddleware.new(app).call(Rack::MockRequest.env_for('http://store1.example.com/'))

      expect(seen).to eq(store)
    end
  end

  describe 'store checkbox on a new product' do
    it 'reports the tenant store before the record is saved' do
      ActsAsTenant.with_tenant(store) do
        product = Spree::Product.new(name: 'New')
        expect(product.store_ids).to eq([store.id])
      end
    end
  end
end
