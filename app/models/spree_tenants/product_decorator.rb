module SpreeTenants
  module ProductDecorator
    def self.prepended(base)
      base.class_eval do
        # Remove the original slug validation from Spree
        _validators.delete(:slug)
        _validate_callbacks.each do |callback|
          if callback.filter.respond_to?(:attributes) && callback.filter.attributes == [:slug]
            _validate_callbacks.delete(callback)
          end
        end
        
        # Add our store-scoped slug validation
        # This ensures slug uniqueness within each store
        validates :slug, presence: true, uniqueness: { 
          scope: :store_id,
          allow_blank: true, 
          case_sensitive: true
        }
        
        # Configure FriendlyId to scope slugs by store_id
        friendly_id :slug_candidates, use: [:history, :scoped, :mobility], scope: :store_id
        
        # Override spree_base_uniqueness_scope to include store_id
        def self.spree_base_uniqueness_scope
          [:store_id]
        end
      end
    end
  end
end

Spree::Product.prepend(SpreeTenants::ProductDecorator)