# frozen_string_literal: true

FactoryBot.define do
  factory :event_amigo_connector do
    association :event
    association :amigo

    role   { :participant }
    status { :pending }

    trait :lead do
      role { :lead_coordinator }
    end

    trait :assistant do
      role { :assistant_coordinator }
    end

    trait :confirmed do
      status { :confirmed }
    end
  end
end
