require 'spec_helper'

# Spree::Store.current / Spree::Current.store must answer with the tenant.
RSpec.describe 'Tenant as the current store', type: :model do
  include_context 'multi_tenant_setup'

  let!(:default_store) { Spree::Store.default }

  describe 'Spree::Store.current and Spree::Current.store' do
    it 'return the tenant when one is set' do
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::Store.current).to eq(another_store)
        expect(Spree::Current.store).to eq(another_store)
      end
    end

    it 'fall back to Spree behaviour without a tenant' do
      ActsAsTenant.without_tenant do
        expect(Spree::Store.current).to eq(default_store)
      end
    end
  end

  describe 'creating a store from another store tenant' do
    it 'gives the new store its own theme, pages and taxonomies' do
      new_store = ActsAsTenant.with_tenant(store) { create(:store, name: 'Store 3', code: 'store3') }

      ActsAsTenant.without_tenant do
        expect(Spree::Theme.where(store_id: new_store.id).count).to eq(1)
        expect(new_store.reload.default_theme).to be_present
        expect(Spree::Page.where(store_id: new_store.id)).to exist
        expect(Spree::Page.where(store_id: new_store.id).count).to eq(Spree::Page.where(pageable: new_store.default_theme).count)
        expect(Spree::Taxonomy.where(store_id: new_store.id).pluck(:name)).to include('Categories')
        expect(Spree::Theme.where(store_id: store.id).count).to eq(1)
      end
    end
  end

  describe 'variants that do not track inventory' do
    it 'get their stock item in their own store default location' do
      product = ActsAsTenant.with_tenant(another_store) { create(:product, track_inventory: false) }

      ActsAsTenant.with_tenant(another_store) do
        product.master.update!(track_inventory: false)
        locations = product.master.stock_items.map(&:stock_location)
        expect(locations).to all(have_attributes(store_id: another_store.id))
        expect(locations.map(&:store_id).uniq).to eq([another_store.id])
      end
    end
  end

  describe 'payment methods created in a store tenant' do
    it 'belong to that store, not the default store' do
      payment_method = ActsAsTenant.with_tenant(another_store) { Spree::PaymentMethod::Check.create!(name: 'B check') }

      expect(payment_method.stores).to eq([another_store])
      expect(default_store.payment_methods).not_to include(payment_method)
    end
  end

  describe 'staff roles' do
    it 'are granted and checked against the tenant store' do
      admin = ActsAsTenant.with_tenant(another_store) { create(:admin_user) }

      ActsAsTenant.with_tenant(another_store) do
        role_user = admin.add_role('admin')
        expect(role_user.resource).to eq(another_store)
        expect(role_user.store_id).to eq(another_store.id)
        expect(admin.spree_admin?).to be true
      end

      ActsAsTenant.with_tenant(store) { expect(admin.spree_admin?).to be false }
      expect(ActsAsTenant.with_tenant(another_store) { another_store.users }).to include(admin)
    end
  end

  describe 'invitations' do
    it 'are scoped to the store that issued them' do
      inviter = ActsAsTenant.with_tenant(store) { create(:admin_user) }
      invitation = ActsAsTenant.with_tenant(store) do
        Spree::Invitation.create!(email: 'new@example.com', inviter: inviter)
      end

      expect(invitation.store_id).to eq(store.id)
      expect(invitation.resource).to eq(store)
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::Invitation.find_by(token: invitation.token)).to be_nil
      end
    end
  end

  describe 'checkout zone cleanup' do
    it 'only touches the zone own store' do
      zone_b = ActsAsTenant.with_tenant(another_store) { Spree::Zone.create!(name: 'B zone', kind: 'country') }
      ActsAsTenant.without_tenant { another_store.update!(checkout_zone_id: zone_b.id) }
      zone_a = ActsAsTenant.with_tenant(store) { Spree::Zone.create!(name: 'A zone', kind: 'country') }
      ActsAsTenant.without_tenant { store.update!(checkout_zone_id: zone_a.id) }

      ActsAsTenant.with_tenant(store) { zone_b.destroy! }

      expect(another_store.reload.checkout_zone_id).to be_nil
      expect(store.reload.checkout_zone_id).to eq(zone_a.id)
    end
  end

  describe 'mailers' do
    it 'use the tenant store when no order is involved' do
      ActsAsTenant.without_tenant { another_store.update!(url: 'store2.example.com') }

      ActsAsTenant.with_tenant(another_store) do
        mailer = Spree::BaseMailer.new
        expect(mailer.current_store).to eq(another_store)
        expect(mailer.default_url_options[:host]).to eq('store2.example.com')
      end
      expect(ActionMailer::Base.default_url_options[:host]).not_to eq('store2.example.com')
    end
  end

  describe 'admin available stores' do
    it 'only lists the store being served' do
      view = Class.new do
        include Spree::Admin::StoresHelper
        attr_accessor :current_store
      end.new
      view.current_store = another_store

      expect(view.available_stores).to eq([another_store])
    end
  end

  describe 'ownership through store_ids' do
    it 'rejects a write naming another store instead of ignoring it' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      ActsAsTenant.without_tenant do
        product.store_ids = [another_store.id]
        expect(product).not_to be_valid
        expect(product.errors[:stores].join).to include('exactly one store')

        product.store_ids = [store.id]
        expect(product).to be_valid
      end
    end
  end

  describe 'product images' do
    it 'take the store of the variant they are attached to' do
      product = ActsAsTenant.with_tenant(store) { create(:product) }

      image = ActsAsTenant.without_tenant do
        Spree::Image.new(viewable: product.master).tap do |img|
          img.attachment.attach(io: StringIO.new('x'), filename: 'x.png', content_type: 'image/png')
          img.save!
        end
      end

      expect(image.store_id).to eq(store.id)
      ActsAsTenant.with_tenant(store) { expect(product.master.reload.images).to include(image) }
      ActsAsTenant.with_tenant(another_store) { expect(Spree::Image.where(id: image.id)).not_to exist }
    end
  end

  describe 'product duplication' do
    it 'derives the copied SKU from the same store only' do
      ActsAsTenant.with_tenant(another_store) { create(:product, sku: 'COPY OF SHARED') }
      product = ActsAsTenant.with_tenant(store) { create(:product, sku: 'SHARED') }

      copy = ActsAsTenant.with_tenant(store) { Spree::Products::Duplicator.call(product: product).value }

      expect(copy.master.sku).to eq('COPY OF SHARED')
    end
  end
end
