# frozen_string_literal: true

FactoryBot.define do
  factory :event_location_connector do
    association :event
    association :event_location

    status { :pending }
    is_primary { false }

    trait :primary do
      is_primary { true }
      status { :confirmed }
    end
  end
end
