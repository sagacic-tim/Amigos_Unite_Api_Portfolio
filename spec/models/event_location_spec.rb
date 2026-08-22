
# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventLocation, type: :model do
  describe "factory" do
    it "has a valid factory" do
      # Avoid any external calls from GeocodableWithFallback
      allow_any_instance_of(EventLocation).to receive(:geocode_with_fallback)
      allow_any_instance_of(EventLocation).to receive(:fetch_time_zone)

      expect(build(:event_location)).to be_valid
    end
  end

  describe ".venue_category?" do
    it "returns true for known venue keywords" do
      expect(described_class.venue_category?("Community Center Hall")).to eq(true)
      expect(described_class.venue_category?("Random Thing")).to eq(false)
    end
  end

  describe "infer_location_type callback" do
    it "infers location_type from business_name when blank" do
      allow_any_instance_of(EventLocation).to receive(:geocode_with_fallback)
      allow_any_instance_of(EventLocation).to receive(:fetch_time_zone)

      loc = build(:event_location, location_type: nil, business_name: "Sunrise Community Center")
      loc.valid?
      expect(loc.location_type).to eq("Community Center")
    end
  end

  describe "search_criteria / search_venue_types validations" do
    before do
      allow_any_instance_of(EventLocation).to receive(:geocode_with_fallback)
      allow_any_instance_of(EventLocation).to receive(:fetch_time_zone)
    end

    it "is valid with search_criteria at the 5-item limit" do
      loc = build(:event_location, search_criteria: %w[a b c d e])
      expect(loc).to be_valid
    end

    it "is invalid with more than 5 search_criteria" do
      loc = build(:event_location, search_criteria: %w[a b c d e f])
      expect(loc).not_to be_valid
      expect(loc.errors[:search_criteria]).to be_present
    end

    it "is valid with search_venue_types at the 3-item limit" do
      loc = build(:event_location, search_venue_types: %w[coffee_shop bar_pub brewery])
      expect(loc).to be_valid
    end

    it "is invalid with more than 3 search_venue_types" do
      loc = build(:event_location, search_venue_types: %w[coffee_shop bar_pub brewery library])
      expect(loc).not_to be_valid
      expect(loc.errors[:search_venue_types]).to be_present
    end

    it "is invalid with an unknown venue type category" do
      loc = build(:event_location, search_venue_types: ["not_a_real_category"])
      expect(loc).not_to be_valid
      expect(loc.errors[:search_venue_types].join).to include("not_a_real_category")
    end
  end
end
