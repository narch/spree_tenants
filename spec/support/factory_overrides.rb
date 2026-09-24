FactoryBot.modify do
  # Spree's taxon factory attaches an icon from a fixture the gem does not ship.
  factory :taxon do
    icon { nil }
  end

  # Products are owned through store_id, not the stores association.
  factory :base_product do
    stores { [] }

    before(:create) do |_product|
      create(:stock_location) unless Spree::StockLocation.any?
    end
  end
end
