
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:event)).to be_valid
    end
  end

  describe "associations" do
    it "requires a lead_coordinator" do
      event = build(:event, lead_coordinator: nil)
      expect(event).not_to be_valid
      expect(event.errors[:lead_coordinator]).to be_present
    end
  end

  describe "enum" do
    it "defines expected statuses" do
      expect(described_class.statuses.keys).to match_array(%w[planning active completed canceled])
    end
  end

  describe "event_speakers_performers normalization" do
    it "strips blanks and whitespace before validation" do
      event = build(:event, event_speakers_performers: [" Alice ", "", "  ", "Bob"])
      event.valid?
      expect(event.event_speakers_performers).to eq(["Alice", "Bob"])
    end
  end

  describe "uniqueness (event_name scoped to date/time)" do
    it "prevents duplicates when date and time are valid" do
      lead = create(:amigo)
      create(:event, lead_coordinator: lead, event_name: "Same", event_date: Date.current, event_time: "10:00")

      dup = build(:event, lead_coordinator: lead, event_name: "Same", event_date: Date.current, event_time: "10:00")
      expect(dup).not_to be_valid
      expect(dup.errors[:event_name].join).to match(/cannot have duplicate/i)
    end

    it "skips uniqueness check when date/time invalid or missing" do
      lead = create(:amigo)
      create(:event, lead_coordinator: lead, event_name: "Same", event_date: Date.current, event_time: "10:00")

      # invalid time => uniqueness validator is skipped per skip_uniqueness_validation?
      dup = build(:event, lead_coordinator: lead, event_name: "Same", event_date: Date.current, event_time: "not-a-time")
      expect(dup).to be_valid
    end
  end
end
