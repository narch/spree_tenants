class RemoveVariantSkuStoreUniqueIndex < ActiveRecord::Migration[8.0]
  def up
    # Remove all existing unique indexes on store_id and sku
    # Spree doesn't enforce SKU uniqueness, so we shouldn't either
    if table_exists?(:spree_variants) && column_exists?(:spree_variants, :sku)
      remove_index :spree_variants, name: 'index_spree_variants_on_store_id_and_sku', if_exists: true
      remove_index :spree_variants, name: 'idx_variants_store_sku', if_exists: true
      remove_index :spree_variants, name: 'index_spree_variants_on_store_id_and_sku_not_blank', if_exists: true
      remove_index :spree_variants, [:store_id, :sku], if_exists: true
    end
  end
  
  def down
    # Restore the store-scoped unique index if rolling back
    # (though this may cause issues since Spree doesn't require unique SKUs)
    if table_exists?(:spree_variants) && column_exists?(:spree_variants, :sku)
      add_index :spree_variants, [:store_id, :sku], 
                unique: true, 
                name: 'index_spree_variants_on_store_id_and_sku',
                if_not_exists: true
    end
  end
end
