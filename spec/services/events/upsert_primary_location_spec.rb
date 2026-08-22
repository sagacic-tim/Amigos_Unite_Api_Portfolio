
# spec/services/events/upsert_primary_location_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::UpsertPrimaryLocation, type: :service do
  let!(:amigo) { create(:amigo) }
  let!(:event) { create(:event, lead_coordinator: amigo) }

  # Defensive: prevent any network-ish work from running during service specs.
  before do
    ensure_stub = lambda do |klass, method_name, return_value = nil|
      if klass.instance_methods.include?(method_name)
        allow_any_instance_of(klass).to receive(method_name).and_return(return_value)
      end
    end

    ensure_stub.call(EventLocation, :fetch_geocoded_data, true)
    ensure_stub.call(EventLocation, :fetch_time_zone, nil)
    ensure_stub.call(EventLocation, :geocode_with_fallback, true)

    allow(URI).to receive(:open).and_raise("Network calls are disabled in service specs")
  end

  def call_service(raw_attrs)
    described_class.new.call(event: event, raw_attrs: raw_attrs)
  end

  let(:base_attrs) do
    {
      business_name: "Original Venue",
      street_name: "Main",
      city: "Springfield",
      state_province: "Missouri",
      country: "United States",
      postal_code: "65804",
      has_food: true
    }
  end

  describe "#call" do
    it "creates a primary location + primary connector when none exists" do
      expect(event.primary_event_location).to be_nil
      expect(event.event_location_connectors.where(is_primary: true)).to be_empty

      call_service(base_attrs)

      event.reload

      primary_location = event.primary_event_location
      expect(primary_location).to be_present
      expect(primary_location.business_name).to eq("Original Venue")

      primary_connector = event.event_location_connectors.find_by(is_primary: true)
      expect(primary_connector).to be_present
      expect(primary_connector.event_location_id).to eq(primary_location.id)
    end

    it "updates the existing primary location when one already exists (no new primary connector)" do
      # Seed an existing primary location via your factories/associations
      existing_location = create(:event_location, business_name: "Seed Venue")
      create(:event_location_connector, :primary, event: event, event_location: existing_location)

      event.reload
      expect(event.primary_event_location).to be_present
      expect(event.primary_event_location.id).to eq(existing_location.id)
      expect(event.event_location_connectors.where(is_primary: true).count).to eq(1)

      call_service(
        business_name: "Updated Venue",
        street_name: "Elm",
        city: "Springfield",
        has_food: false
      )

      event.reload

      # Still exactly one primary connector
      expect(event.event_location_connectors.where(is_primary: true).count).to eq(1)

      # Primary location record is reused (id stable) and updated
      updated_location = event.primary_event_location
      expect(updated_location.id).to eq(existing_location.id)
      expect(updated_location.business_name).to eq("Updated Venue")
      expect(updated_location.street_name).to eq("Elm")
      expect(updated_location.has_food).to eq(false)
    end

    it "never creates a second primary connector (guards unique primary constraint)" do
      existing_location = create(:event_location, business_name: "Seed Venue")
      create(:event_location_connector, :primary, event: event, event_location: existing_location)

      expect(event.event_location_connectors.where(is_primary: true).count).to eq(1)

      call_service(business_name: "Another Update")

      event.reload
      expect(event.event_location_connectors.where(is_primary: true).count).to eq(1)
    end

    it "persists search_criteria and search_venue_types" do
      call_service(
        base_attrs.merge(
          search_criteria: ["cozy", "quiet"],
          search_venue_types: ["coffee_shop", "bar_pub"]
        )
      )

      event.reload
      primary_location = event.primary_event_location
      expect(primary_location.search_criteria).to eq(["cozy", "quiet"])
      expect(primary_location.search_venue_types).to eq(["coffee_shop", "bar_pub"])
    end

    it "strips blank entries and caps to 5 criteria / 3 venue types" do
      call_service(
        base_attrs.merge(
          search_criteria: ["a", " ", "b", "c", "d", "e", "f"],
          search_venue_types: ["coffee_shop", "bar_pub", "brewery", "library"]
        )
      )

      event.reload
      primary_location = event.primary_event_location
      expect(primary_location.search_criteria).to eq(["a", "b", "c", "d", "e"])
      expect(primary_location.search_venue_types).to eq(["coffee_shop", "bar_pub", "brewery"])
    end

    it "treats an absent search_criteria/search_venue_types key as empty, not unchanged" do
      existing_location = create(:event_location, business_name: "Seed Venue",
                                                    search_criteria: ["old criterion"],
                                                    search_venue_types: ["library"])
      create(:event_location_connector, :primary, event: event, event_location: existing_location)

      call_service(business_name: "Updated Venue")

      event.reload
      primary_location = event.primary_event_location
      expect(primary_location.search_criteria).to eq([])
      expect(primary_location.search_venue_types).to eq([])
    end
  end
end
