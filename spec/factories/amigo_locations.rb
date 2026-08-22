# spec/factories/amigo_locations.rb
# frozen_string_literal: true

FactoryBot.define do
  factory :amigo_location do
    association :amigo

    address { "123 Maple Street, Springfield, IL 62704" }

    # Keep these nil so GeocodableWithFallback won't have enough component data
    # to call geocoding, and your record still passes validations (address-only).
    street_number { nil }
    street_name   { nil }
    city          { nil }

    latitude  { nil }
    longitude { nil }
    time_zone { nil }
  end
end
