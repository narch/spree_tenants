require 'spec_helper'

RSpec.describe Spree::TaxRate, type: :model do
  include_context 'multi_tenant_setup'
  
  describe 'tenant behavior' do
    it 'automatically sets store_id when tenant is set' do
      ActsAsTenant.with_tenant(store) do
        tax_category = create(:tax_category)
        tax_rate = Spree::TaxRate.new(
          name: 'VAT',
          amount: 0.20,
          calculator: Spree::Calculator::DefaultTax.new,
          tax_category: tax_category
        )
        
        expect(tax_rate.store_id).to eq(store.id)
      end
    end

    it 'creates tax rates within tenant context' do
      ActsAsTenant.with_tenant(store) do
        tax_category = create(:tax_category)
        tax_rate = Spree::TaxRate.create!(
          name: 'VAT',
          amount: 0.20,
          calculator: Spree::Calculator::DefaultTax.new,
          tax_category: tax_category
        )
        
        expect(tax_rate.store_id).to eq(store.id)
      end
    end

    it 'scopes queries to current tenant' do
      ActsAsTenant.with_tenant(store) do
        tax_category = create(:tax_category)
        tax_rate = Spree::TaxRate.create!(
          name: 'VAT',
          amount: 0.20,
          calculator: Spree::Calculator::DefaultTax.new,
          tax_category: tax_category
        )
      end
      
      ActsAsTenant.with_tenant(another_store) do
        tax_category2 = create(:tax_category)
        tax_rate2 = Spree::TaxRate.create!(
          name: 'Sales Tax',
          amount: 0.08,
          calculator: Spree::Calculator::DefaultTax.new,
          tax_category: tax_category2
        )
      end
      
      ActsAsTenant.with_tenant(store) do
        expect(Spree::TaxRate.count).to eq(1)
        expect(Spree::TaxRate.first.name).to eq('VAT')
      end
      
      ActsAsTenant.with_tenant(another_store) do
        expect(Spree::TaxRate.count).to eq(1)
        expect(Spree::TaxRate.first.name).to eq('Sales Tax')
      end
    end
  end
end
