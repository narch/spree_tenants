class FixVariantSkuUniqueIndex < ActiveRecord::Migration[7.2]
  def up
    # Remove all existing indexes on store_id and sku
    remove_index :spree_variants, name: 'index_spree_variants_on_store_id_and_sku', if_exists: true
    remove_index :spree_variants, name: 'idx_variants_store_sku', if_exists: true
    
    # Add a partial unique index that allows multiple blank SKUs per store
    # This uses a WHERE clause to only enforce uniqueness for non-blank SKUs
    add_index :spree_variants, [:store_id, :sku], 
              unique: true, 
              where: "sku IS NOT NULL AND sku != ''",
              name: 'index_spree_variants_on_store_id_and_sku_not_blank'
  end
  
  def down
    # Remove the partial index
    remove_index :spree_variants, name: 'index_spree_variants_on_store_id_and_sku_not_blank', if_exists: true
    
    # Restore the original index (though this might cause issues with blank SKUs)
    add_index :spree_variants, [:store_id, :sku], unique: true, name: 'index_spree_variants_on_store_id_and_sku'
  end
end