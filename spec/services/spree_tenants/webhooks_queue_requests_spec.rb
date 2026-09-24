require 'spec_helper'

RSpec.describe Spree::Webhooks::Subscribers::QueueRequests do
  include_context 'multi_tenant_setup'

  let!(:store_subscriber) do
    ActsAsTenant.with_tenant(store) do
      Spree::Webhooks::Subscriber.create!(url: 'https://one.example.com/hook', active: true, subscriptions: ['*'])
    end
  end
  let!(:other_subscriber) do
    ActsAsTenant.with_tenant(another_store) do
      Spree::Webhooks::Subscriber.create!(url: 'https://two.example.com/hook', active: true, subscriptions: ['*'])
    end
  end
  let(:order) { ActsAsTenant.with_tenant(store) { create(:order) } }

  def queued_subscribers
    queued = []
    allow(Spree::Webhooks::Subscribers::MakeRequestJob).to receive(:perform_later) do |_body, _event, subscriber|
      queued << subscriber
    end
    yield
    queued
  end

  it 'only queues the record store subscribers when no tenant is set' do
    queued = queued_subscribers do
      ActsAsTenant.without_tenant do
        described_class.call(event_name: 'order.paid', webhook_payload_body: '{}', record: order)
      end
    end

    expect(queued).to eq([store_subscriber])
  end

  it 'queues the record store subscribers even when the ambient tenant differs' do
    queued = queued_subscribers do
      ActsAsTenant.with_tenant(another_store) do
        described_class.call(event_name: 'order.paid', webhook_payload_body: '{}', record: order)
      end
    end

    expect(queued).to eq([store_subscriber])
  end

  it 'queues nothing when neither the record nor the context names a store' do
    queued = queued_subscribers do
      ActsAsTenant.without_tenant do
        described_class.call(event_name: 'order.paid', webhook_payload_body: '{}', record: nil)
      end
    end

    expect(queued).to be_empty
  end
end
