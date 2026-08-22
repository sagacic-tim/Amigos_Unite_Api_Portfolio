# spec/factories/amigos.rb
# frozen_string_literal: true

FactoryBot.define do
  sequence(:amigo_user_name_short) { |n| "amigo#{n}" }
  sequence(:amigo_email_test)      { |n| "amigo#{n}@example.test" }

  factory :amigo do
    sequence(:user_name) { |n| "amigo_user_#{n}" }
    sequence(:email)     { |n| "amigo#{n}@example.com" }

    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }

    password              { "Password12345!" }
    password_confirmation { password }

    role { :amigo }

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :static_names do
      first_name { "Test" }
      last_name  { "Amigo" }
    end

    trait :example_test_identity do
      user_name  { generate(:amigo_user_name_short) }
      email      { generate(:amigo_email_test) }
      first_name { "Test" }
      last_name  { "Amigo" }
    end
  end
end
