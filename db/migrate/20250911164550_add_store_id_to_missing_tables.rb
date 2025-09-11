class AddStoreIdToMissingTables < ActiveRecord::Migration[8.0]
  def change
    # Content Management Tables
    add_column :spree_pages, :store_id, :integer, null: false, default: 1
    add_column :spree_page_blocks, :store_id, :integer, null: false, default: 1
    add_column :spree_page_links, :store_id, :integer, null: false, default: 1
    add_column :spree_page_sections, :store_id, :integer, null: false, default: 1

    # Refunds & Returns
    add_column :spree_refund_reasons, :store_id, :integer, null: false, default: 1
    add_column :spree_reimbursement_types, :store_id, :integer, null: false, default: 1
    add_column :spree_return_authorization_reasons, :store_id, :integer, null: false, default: 1

    # Store Credits & Gift Cards
    add_column :spree_store_credit_categories, :store_id, :integer, null: false, default: 1
    add_column :spree_store_credit_types, :store_id, :integer, null: false, default: 1

    # Webhooks & Integrations
    add_column :spree_webhooks_events, :store_id, :integer, null: false, default: 1
    add_column :spree_webhooks_subscribers, :store_id, :integer, null: false, default: 1

    # Other Important Tables
    add_column :spree_promotion_categories, :store_id, :integer, null: false, default: 1
    add_column :spree_stock_transfers, :store_id, :integer, null: false, default: 1
    add_column :spree_digitals, :store_id, :integer, null: false, default: 1

    # Add indexes for performance
    add_index :spree_pages, :store_id
    add_index :spree_page_blocks, :store_id
    add_index :spree_page_links, :store_id
    add_index :spree_page_sections, :store_id
    add_index :spree_refund_reasons, :store_id
    add_index :spree_reimbursement_types, :store_id
    add_index :spree_return_authorization_reasons, :store_id
    add_index :spree_store_credit_categories, :store_id
    add_index :spree_store_credit_types, :store_id
    add_index :spree_webhooks_events, :store_id
    add_index :spree_webhooks_subscribers, :store_id
    add_index :spree_promotion_categories, :store_id
    add_index :spree_stock_transfers, :store_id
    add_index :spree_digitals, :store_id

    # Add store-scoped unique constraints where appropriate
    add_index :spree_refund_reasons, [:store_id, :name], unique: true
    add_index :spree_reimbursement_types, [:store_id, :name], unique: true
    add_index :spree_return_authorization_reasons, [:store_id, :name], unique: true
    add_index :spree_store_credit_categories, [:store_id, :name], unique: true
    add_index :spree_store_credit_types, [:store_id, :name], unique: true
    add_index :spree_promotion_categories, [:store_id, :name], unique: true

    # Add foreign key constraints
    add_foreign_key :spree_pages, :spree_stores, column: :store_id
    add_foreign_key :spree_page_blocks, :spree_stores, column: :store_id
    add_foreign_key :spree_page_links, :spree_stores, column: :store_id
    add_foreign_key :spree_page_sections, :spree_stores, column: :store_id
    add_foreign_key :spree_refund_reasons, :spree_stores, column: :store_id
    add_foreign_key :spree_reimbursement_types, :spree_stores, column: :store_id
    add_foreign_key :spree_return_authorization_reasons, :spree_stores, column: :store_id
    add_foreign_key :spree_store_credit_categories, :spree_stores, column: :store_id
    add_foreign_key :spree_store_credit_types, :spree_stores, column: :store_id
    add_foreign_key :spree_webhooks_events, :spree_stores, column: :store_id
    add_foreign_key :spree_webhooks_subscribers, :spree_stores, column: :store_id
    add_foreign_key :spree_promotion_categories, :spree_stores, column: :store_id
    add_foreign_key :spree_stock_transfers, :spree_stores, column: :store_id
    add_foreign_key :spree_digitals, :spree_stores, column: :store_id
  end
end
