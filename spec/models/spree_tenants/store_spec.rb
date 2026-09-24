require 'spec_helper'

RSpec.describe Spree::Store, type: :model do
  let(:store) { create(:store, name: 'Store 1', code: 'store1') }
  let(:another_store) { create(:store, name: 'Store 2', code: 'store2') }

  describe 'basic validation' do
    it 'creates a valid store' do
      expect(store).to be_valid
      expect(store).to be_persisted
      expect(store.id).to be_present
      expect(store.name).to eq('Store 1')
      expect(store.code).to eq('store1')
    end

    it 'creates another valid store' do
      expect(another_store).to be_valid
      expect(another_store).to be_persisted
      expect(another_store.id).to be_present
      expect(another_store.name).to eq('Store 2')
      expect(another_store.code).to eq('store2')
    end

    it 'stores are different' do
      expect(store.id).not_to eq(another_store.id)
      expect(store.code).not_to eq(another_store.code)
    end
  end

  describe 'tenant behavior' do
    it 'sets current tenant' do
      ActsAsTenant.with_tenant(store) do
        expect(ActsAsTenant.current_tenant).to eq(store)
        expect(ActsAsTenant.current_tenant.id).to eq(store.id)
      end
    end

    it 'switches tenants correctly' do
      ActsAsTenant.with_tenant(store) do
        expect(ActsAsTenant.current_tenant).to eq(store)
      end

      ActsAsTenant.with_tenant(another_store) do
        expect(ActsAsTenant.current_tenant).to eq(another_store)
      end

      expect(ActsAsTenant.current_tenant).to be_nil
    end
  end
  
  describe 'associations' do
    it 'keeps Spree products association, fed by the mirrored join rows' do
      association = Spree::Store.reflect_on_association(:products)
      expect(association.options[:through]).to eq(:store_products)
    end

    it 'keeps Spree has_many :through chains valid' do
      %i[variants product_properties line_items shipments payments stock_items].each do |name|
        expect { Spree::Store.reflect_on_association(name).check_validity! }.not_to raise_error
      end
    end
    
    it 'has many orders' do
      association = Spree::Store.reflect_on_association(:orders)
      expect(association).to be_present
      expect(association.macro).to eq(:has_many)
      expect(association.foreign_key.to_s).to eq('store_id')
    end

    it 'has many taxonomies' do
      association = Spree::Store.reflect_on_association(:taxonomies)
      expect(association).to be_present
      expect(association.macro).to eq(:has_many)
      expect(association.foreign_key.to_s).to eq('store_id')
    end
    
    it 'has many variants through products' do
      association = Spree::Store.reflect_on_association(:variants)
      expect(association).to be_present
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:products)
    end
  end
  
  describe '#with_tenant' do
    it 'executes block with store as tenant' do
      product = nil
      
      store.with_tenant do
        product = create(:product, store_id: store.id)
        expect(ActsAsTenant.current_tenant).to eq(store)
      end
      
      expect(product.store_id).to eq(store.id)
    end
    
    it 'isolates data between stores' do
      product1 = nil
      product2 = nil
      
      store.with_tenant do
        product1 = create(:product, store_id: store.id)
      end
      
      another_store.with_tenant do
        product2 = create(:product, store_id: another_store.id)
        products = Spree::Product.all
        expect(products).to include(product2)
        expect(products).not_to include(product1)
      end
    end
  end
  
  describe '#all_products' do
    before do
      ActsAsTenant.with_tenant(store) do
        create(:product, store_id: store.id)
      end
      ActsAsTenant.with_tenant(another_store) do
        create(:product, store_id: another_store.id)
      end
    end
    
    it 'returns products for this store only, bypassing current tenant' do
      ActsAsTenant.with_tenant(another_store) do
        products = store.all_products
        expect(products.count).to eq(1)
        expect(products.first.store_id).to eq(store.id)
      end
    end
  end
  
  describe '#all_orders' do
    before do
      ActsAsTenant.with_tenant(store) do
        create(:order, store_id: store.id)
      end
      ActsAsTenant.with_tenant(another_store) do
        create(:order, store_id: another_store.id)
      end
    end
    
    it 'returns orders for this store only, bypassing current tenant' do
      ActsAsTenant.with_tenant(another_store) do
        orders = store.all_orders
        expect(orders.count).to eq(1)
        expect(orders.first.store_id).to eq(store.id)
      end
    end
  end
  
  describe 'importing products from another store' do
    it 'is refused because products belong to exactly one store' do
      ActsAsTenant.with_tenant(store) { create(:product, store_id: store.id) }

      new_store = build(:store, name: 'Store 3', code: 'store3', import_products_from_store_id: store.id.to_s)

      expect(new_store).not_to be_valid
      expect(new_store.errors[:import_products_from_store_id].join).to include('not supported')
    end

    it 'still allows importing payment methods' do
      payment_method = Spree::PaymentMethod::Check.create!(name: 'Check', stores: [store])

      new_store = create(:store, name: 'Store 3', code: 'store3', import_payment_methods_from_store_id: store.id.to_s)

      expect(new_store.payment_methods).to include(payment_method)
    end
  end

  describe 'provisioning on create' do
    it 'creates the per-store records a tenant needs, in the same transaction' do
      new_store = create(:store, name: 'Store 3', code: 'store3')

      ActsAsTenant.with_tenant(new_store) do
        expect(Spree::Role.pluck(:name)).to match_array(%w[admin user])
        expect(Spree::ShippingCategory.pluck(:name)).to match_array(%w[Default Digital])
        expect(Spree::StockLocation.where(default: true).count).to eq(1)
        expect(Spree::TaxCategory.where(is_default: true).count).to eq(1)
        expect(Spree::TaxCategory.pluck(:name)).to match_array(['Default', 'Non-taxable'])
        digital = Spree::ShippingMethod.find_by!(name: Spree.t('digital.digital_delivery'))
        expect(digital.calculator).to be_a(Spree::Calculator::Shipping::DigitalDelivery)
        expect(digital.shipping_categories.map(&:name)).to eq(['Digital'])
        expect(digital.zones.map(&:store_id).uniq).to eq([new_store.id])
        expect(new_store.payment_methods.map(&:type)).to include('Spree::PaymentMethod::StoreCredit')
        expect(Spree::StoreCreditCategory.count).to eq(3)
        expect(Spree::RefundReason.count).to eq(1)
        expect(Spree::ReturnAuthorizationReason.count).to eq(9)
        expect(Spree::ReimbursementType.count).to eq(3)
      end
    end

    it 'can be switched off' do
      SpreeTenants::Config.provision_new_stores = false
      new_store = create(:store, name: 'Store 3', code: 'store3')

      expect(ActsAsTenant.with_tenant(new_store) { Spree::Role.count }).to eq(0)
    ensure
      SpreeTenants::Config.provision_new_stores = true
    end
  end

  describe '#add_user' do
    let(:new_store) { create(:store, name: 'Store 3', code: 'store3') }

    it 'refuses staff from another store' do
      foreign_admin = ActsAsTenant.with_tenant(store) { create(:admin_user) }

      expect(new_store.add_user(foreign_admin)).to be_nil
      expect(ActsAsTenant.with_tenant(new_store) { new_store.users }).to be_empty
    end

    it 'maps a role from another store to this store role and scopes the assignment to this store' do
      source_role = ActsAsTenant.with_tenant(store) { Spree::Role.find_by!(name: 'admin') }
      local_admin = ActsAsTenant.with_tenant(new_store) { create(:admin_user) }

      role_user = new_store.add_user(local_admin, source_role)

      expect(role_user.store_id).to eq(new_store.id)
      expect(role_user.role.store_id).to eq(new_store.id)
      expect(role_user.role.name).to eq('admin')
      expect(ActsAsTenant.with_tenant(new_store) { new_store.users }).to include(local_admin)
    end

    it 'uses this store admin role by default' do
      local_admin = ActsAsTenant.with_tenant(new_store) { create(:admin_user) }

      role_user = new_store.add_user(local_admin)

      expect(role_user.role.store_id).to eq(new_store.id)
      expect(role_user.role.name).to eq('admin')
    end
  end

  describe 'StoreProvisioner.create_admin!' do
    it 'creates a per-store admin with the store admin role' do
      new_store = create(:store, name: 'Store 3', code: 'store3')

      admin = SpreeTenants::StoreProvisioner.create_admin!(new_store, email: 'boss@example.com', password: 'password123')

      expect(admin.store_id).to eq(new_store.id)
      ActsAsTenant.with_tenant(new_store) do
        expect(new_store.users).to include(admin)
        expect(admin.has_spree_role?('admin', new_store)).to be true
      end
      expect(ActsAsTenant.with_tenant(store) { new_store.users.to_a }).to be_empty
    end
  end

  describe '#users and #customer_users' do
    it 'keeps Spree users as staff and exposes customers separately' do
      staff = Spree::Store.reflect_on_association(:users)
      expect(staff.options[:through]).to eq(:role_users)

      customers = Spree::Store.reflect_on_association(:customer_users)
      expect(customers.klass).to eq(Spree.user_class)
      expect(customers.foreign_key.to_s).to eq('store_id')
    end
  end

  describe 'dependent associations' do
    it 'restricts deletion when products exist' do
      ActsAsTenant.with_tenant(store) do
        create(:product, store_id: store.id)
      end
      
      expect(store.destroy).to be false
      expect(store.errors[:base].join).to include('Cannot delete record')
      expect(store.reload.deleted_at).to be_nil
    end

    it 'restricts deletion when orders exist' do
      ActsAsTenant.with_tenant(store) do
        create(:order, store_id: store.id)
      end

      expect(store.destroy).to be false
      expect(store.errors[:base].join).to include('Cannot delete record')
      expect(store.reload.deleted_at).to be_nil
    end
  end
end