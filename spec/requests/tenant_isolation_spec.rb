require 'spec_helper'

RSpec.describe 'Tenant isolation across stores', type: :request do
  include_context 'multi_tenant_setup'

  let!(:store_product) do
    ActsAsTenant.with_tenant(store) { create(:product_in_stock, name: 'Store One Widget', price: 10) }
  end
  let!(:other_product) do
    ActsAsTenant.with_tenant(another_store) { create(:product_in_stock, name: 'Store Two Gadget', price: 10) }
  end

  before do
    ActsAsTenant.without_tenant do
      store.update!(url: 'store1.example.com')
      another_store.update!(url: 'store2.example.com')
    end
  end

  describe 'storefront' do
    it 'sets the tenant from the host for the whole action' do
      seen_tenant = nil
      allow_any_instance_of(Spree::ProductsController).to receive(:index).and_wrap_original do |original, *args|
        seen_tenant = ActsAsTenant.current_tenant
        original.call(*args)
      end

      host! 'store2.example.com'
      get '/products'

      expect(seen_tenant).to eq(another_store)
      expect(ActsAsTenant.current_tenant).to be_nil
    end

    it 'lists only the current store products' do
      host! 'store1.example.com'
      get '/products'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Store One Widget')
      expect(response.body).not_to include('Store Two Gadget')
    end

    it 'does not expose another store product by slug' do
      host! 'store1.example.com'
      get "/products/#{other_product.slug}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'cart' do
    it 'adds the current store variant and refuses another store variant' do
      host! 'store1.example.com'

      post '/line_items', params: { variant_id: store_product.master.id, quantity: 1 }
      expect(response.status).to be_between(200, 302), response.body
      expect(Spree::Order.unscoped.last.line_items.map(&:variant_id)).to eq([store_product.master.id])

      post '/line_items', params: { variant_id: other_product.master.id, quantity: 1 }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'admin' do
    it 'sets the tenant before authorization runs' do
      seen_tenant = :unset
      allow_any_instance_of(Spree::Admin::BaseController).to receive(:authorize_admin).and_wrap_original do |original, *args|
        seen_tenant = ActsAsTenant.current_tenant
        original.call(*args)
      end

      host! 'store2.example.com'
      get '/admin/products'

      expect(seen_tenant).to eq(another_store)
    end
  end

  describe 'API v2 storefront' do
    it 'lists only the current store products' do
      host! 'store1.example.com'
      get '/api/v2/storefront/products'

      expect(response).to have_http_status(:ok)
      names = JSON.parse(response.body).fetch('data').map { |row| row.dig('attributes', 'name') }
      expect(names).to include('Store One Widget')
      expect(names).not_to include('Store Two Gadget')
    end

    it 'does not expose another store product' do
      host! 'store1.example.com'
      get "/api/v2/storefront/products/#{other_product.slug}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
