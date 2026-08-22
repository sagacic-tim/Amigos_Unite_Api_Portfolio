
# spec/services/events/create_event_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::CreateEvent, type: :service do
  let!(:amigo) { create(:amigo) }

  # Defensive: prevent any network-ish work from running during service specs.
  before do
    # If your EventLocation callbacks reference these methods, stub them safely.
    ensure_stub = lambda do |klass, method_name, return_value = nil|
      if klass.instance_methods.include?(method_name)
        allow_any_instance_of(klass).to receive(method_name).and_return(return_value)
      end
    end

    ensure_stub.call(EventLocation, :fetch_geocoded_data, true)
    ensure_stub.call(EventLocation, :fetch_time_zone, nil)
    ensure_stub.call(EventLocation, :geocode_with_fallback, true)

    # If anything attempts to fetch remote images, block it (defensive).
    allow(URI).to receive(:open).and_raise("Network calls are disabled in service specs")
  end

  def call_service(attrs)
    described_class.new.call(creator: amigo, attrs: attrs)
  end

  describe "#call" do
    it "creates the event and sets lead_coordinator_id" do
      attrs = {
        event_name: "Service Event",
        event_type: "Meetup",
        event_date: Date.current.to_s,
        event_time: "18:00",
        status: "planning",
        description: "hello",
        event_speakers_performers: ["Alice", " Bob ", ""]
      }

      event = call_service(attrs)

      expect(event).to be_persisted
      expect(event.lead_coordinator_id).to eq(amigo.id)
      expect(event.event_name).to eq("Service Event")

      # Normalization behavior from Event model callback(s)
      expect(event.event_speakers_performers).to eq(["Alice", "Bob"])
    end

    it "creates a lead EventAmigoConnector for the creator" do
      attrs = {
        event_name: "Lead Connector Event",
        event_type: "Meetup",
        event_date: Date.current.to_s,
        event_time: "18:00",
        status: "planning"
      }

      event = call_service(attrs)

      lead_connectors = event.event_amigo_connectors.lead_coordinator
      expect(lead_connectors.count).to eq(1)
      expect(lead_connectors.first.amigo_id).to eq(amigo.id)
    end

    it "when location attrs are present, creates/links a primary event location" do
      attrs = {
        event_name: "Location Event",
        event_type: "Meetup",
        event_date: Date.current.to_s,
        event_time: "18:00",
        status: "planning",
        location: {
          business_name: "Dancing Mule Coffee Company",
          street_number: "1945",
          street_name: "South Glenstone Avenue",
          city: "Springfield",
          state_province: "Missouri",
          country: "United States",
          postal_code: "65804",
          has_food: true,
          has_drink: true
        }
      }

      event = call_service(attrs)
      event.reload

      # Contract: service should create the primary location relationship.
      primary_location = event.primary_event_location
      expect(primary_location).to be_present
      expect(primary_location.business_name).to eq("Dancing Mule Coffee Company")

      # And it should be linked as primary via connector.
      primary_connector = event.event_location_connectors.find_by(is_primary: true)
      expect(primary_connector).to be_present
      expect(primary_connector.event_location_id).to eq(primary_location.id)
    end
  end
end
