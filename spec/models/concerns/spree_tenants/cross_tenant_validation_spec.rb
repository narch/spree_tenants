require 'spec_helper'

RSpec.describe SpreeTenants::CrossTenantValidation do
  # Create a test model that includes the concern
  with_model :TestModel do
    table do |t|
      t.integer :store_id
      t.string :name
      t.integer :parent_id
      t.timestamps
    end

    model do
      include SpreeTenants::CrossTenantValidation
      acts_as_tenant :store, foreign_key: 'store_id', class_name: 'Spree::Store'
      
      belongs_to :parent, class_name: 'TestModel', optional: true
      has_many :children, class_name: 'TestModel', foreign_key: 'parent_id'
      
      # Test the validation helpers
      validate_same_store_for :parent
      validates_uniqueness_scoped_to_store :name
    end
  end
  
  let(:store) { create(:store) }
  let(:another_store) { create(:store) }
  
  describe '.validate_same_store_for' do
    it 'validates associated records belong to same store' do
      parent = TestModel.create!(name: 'Parent', store_id: store.id)
      child = TestModel.new(name: 'Child', store_id: store.id, parent: parent)
      
      expect(child).to be_valid
    end
    
    it 'adds error when associated record is from different store' do
      parent = TestModel.create!(name: 'Parent', store_id: another_store.id)
      child = TestModel.new(name: 'Child', store_id: store.id, parent: parent)
      
      expect(child).not_to be_valid
      expect(child.errors[:parent]).to include('must belong to the same store')
    end
    
    it 'handles nil associations' do
      child = TestModel.new(name: 'Child', store_id: store.id, parent: nil)
      expect(child).to be_valid
    end
  end
  
  describe '.validates_uniqueness_scoped_to_store' do
    it 'allows same name in different stores' do
      TestModel.create!(name: 'Duplicate', store_id: store.id)
      duplicate = TestModel.new(name: 'Duplicate', store_id: another_store.id)
      
      expect(duplicate).to be_valid
    end
    
    it 'prevents duplicate names within same store' do
      TestModel.create!(name: 'Duplicate', store_id: store.id)
      duplicate = TestModel.new(name: 'Duplicate', store_id: store.id)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end
    
    it 'is case insensitive by default' do
      TestModel.create!(name: 'duplicate', store_id: store.id)
      duplicate = TestModel.new(name: 'DUPLICATE', store_id: store.id)
      
      expect(duplicate).not_to be_valid
    end
  end
  
  describe '#same_store?' do
    let(:model) { TestModel.new(store_id: store.id) }
    
    it 'returns true for records from same store' do
      other = TestModel.new(store_id: store.id)
      expect(model.same_store?(other)).to be true
    end
    
    it 'returns false for records from different stores' do
      other = TestModel.new(store_id: another_store.id)
      expect(model.same_store?(other)).to be false
    end
    
    it 'returns true for objects without store_id' do
      other = double('non-tenant-object')
      expect(model.same_store?(other)).to be true
    end
  end
  
  describe '#filter_by_same_store' do
    let!(:store_record1) { TestModel.create!(name: 'Record 1', store_id: store.id) }
    let!(:store_record2) { TestModel.create!(name: 'Record 2', store_id: store.id) }
    let!(:another_store_record) { TestModel.create!(name: 'Record 3', store_id: another_store.id) }
    
    it 'filters collection to same store records' do
      model = TestModel.new(store_id: store.id)
      filtered = model.filter_by_same_store(TestModel.all)
      
      expect(filtered).to include(store_record1, store_record2)
      expect(filtered).not_to include(another_store_record)
    end
    
    it 'returns original collection when store_id is nil' do
      model = TestModel.new(store_id: nil)
      filtered = model.filter_by_same_store(TestModel.all)
      
      expect(filtered.count).to eq(3)
    end
  end
  
  describe 'complex validation scenario' do
    with_model :ComplexModel do
      table do |t|
        t.integer :store_id
        t.string :code
        t.string :status
        t.timestamps
      end

      model do
        include SpreeTenants::CrossTenantValidation
        acts_as_tenant :store, foreign_key: 'store_id', class_name: 'Spree::Store'
        
        # Test with additional scope
        validates_uniqueness_scoped_to_store :code, scope: :status
      end
    end
    
    it 'handles additional scopes with store_id' do
      ComplexModel.create!(code: 'ABC', status: 'active', store_id: store.id)
      
      # Same code, same status, same store - invalid
      duplicate = ComplexModel.new(code: 'ABC', status: 'active', store_id: store.id)
      expect(duplicate).not_to be_valid
      
      # Same code, different status, same store - valid
      different_status = ComplexModel.new(code: 'ABC', status: 'inactive', store_id: store.id)
      expect(different_status).to be_valid
      
      # Same code, same status, different store - valid
      different_store = ComplexModel.new(code: 'ABC', status: 'active', store_id: another_store.id)
      expect(different_store).to be_valid
    end
  end
end