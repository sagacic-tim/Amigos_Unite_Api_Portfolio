# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    association :lead_coordinator, factory: :amigo

    event_name { "Amigos Meetup #{SecureRandom.hex(3)}" }
    event_type { "Meetup" }
    event_date { Date.current + 7.days }
    event_time { Time.zone.parse("18:30") }
    status     { :planning }
    description { "A community meetup event." }

    # schema default is [] and model normalizes; keep explicit for clarity
    event_speakers_performers { ["Speaker One", " Speaker Two ", ""] }

    trait :with_clean_speakers do
      event_speakers_performers { ["Alice", "Bob"] }
    end
  end
end
