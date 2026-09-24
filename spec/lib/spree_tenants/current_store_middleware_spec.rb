require 'spec_helper'

RSpec.describe SpreeTenants::CurrentStoreMiddleware do
  include_context 'multi_tenant_setup'

  before do
    ActsAsTenant.without_tenant do
      store.update!(url: 'store1.example.com')
      another_store.update!(url: 'store2.example.com')
    end
  end

  let(:seen) { {} }
  let(:app) do
    lambda do |_env|
      seen[:tenant] = ActsAsTenant.current_tenant
      [200, { 'Content-Type' => 'text/plain' }, ['ok']]
    end
  end
  let(:middleware) { described_class.new(app) }

  it 'sets the tenant from the request host for any Rack endpoint' do
    middleware.call(Rack::MockRequest.env_for('http://store2.example.com/admin/login'))
    expect(seen[:tenant]).to eq(another_store)

    middleware.call(Rack::MockRequest.env_for('http://store1.example.com/users/sign_in'))
    expect(seen[:tenant]).to eq(store)
  end

  it 'clears the tenant once the response body is closed' do
    _status, _headers, body = middleware.call(Rack::MockRequest.env_for('http://store1.example.com/'))
    expect(ActsAsTenant.current_tenant).to eq(store)

    body.close
    expect(ActsAsTenant.current_tenant).to be_nil
  end

  it 'scopes user lookups the way Devise authentication would' do
    user_class = Spree.user_class
    ActsAsTenant.with_tenant(store) { user_class.create!(email: 'same@example.com', password: 'password123') }
    ActsAsTenant.with_tenant(another_store) { user_class.create!(email: 'same@example.com', password: 'password123') }

    lookup = ->(_env) { [200, {}, [user_class.where(email: 'same@example.com').pluck(:store_id).join(',')]] }
    status, _headers, body = described_class.new(lookup).call(Rack::MockRequest.env_for('http://store2.example.com/users/sign_in'))

    expect(status).to eq(200)
    expect(body.join).to eq(another_store.id.to_s)
  end

  it 'is installed in the application middleware stack' do
    expect(Rails.application.middleware.map(&:name)).to include('SpreeTenants::CurrentStoreMiddleware')
  end
end
