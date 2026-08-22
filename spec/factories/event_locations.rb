# frozen_string_literal: true

FactoryBot.define do
  factory :event_location do
    business_name { "Dancing Mule Coffee Company" }
    business_phone { "4175551212" }

    # Keep address components populated so Geocodable concern can build address without net calls
    street_number { "1945" }
    street_name   { "South Glenstone Avenue" }
    city          { "Springfield" }
    state_province { "Missouri" }
    state_province_short { "MO" }
    country       { "United States" }
    country_short { "US" }
    postal_code   { "65804" }

    location_type { "Cafe" }
    owner_name    { "Owner Name" }

    capacity { 50 }
    capacity_seated { 30 }
    availability_notes { "Evenings best." }

    has_food       { true }
    has_drink      { true }
    has_internet   { true }
    has_big_screen { false }

    place_id { "place_#{SecureRandom.hex(6)}" }
    location_image_attribution { "Photo by Example" }

    # Provide coords to avoid geocoding/timezone lookups
    latitude  { 37.1601 }
    longitude { -93.2466 }
    time_zone { "America/Chicago" }

    status { :pending }
  end
end
