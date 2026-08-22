# spec/requests/events_spec.rb
# frozen_string_literal: true

require "rails_helper"

# -----------------------------------------------------------------------------
# JSON:API helpers (scoped to this file)
# -----------------------------------------------------------------------------
def json
  JSON.parse(response.body)
end

def json_data
  json.fetch("data")
end

def json_id(resource)
  resource.fetch("id").to_i
end

def json_type(resource)
  resource.fetch("type")
end

def json_attrs(resource)
  resource.fetch("attributes")
end

def json_relationship(resource, name)
  resource.fetch("relationships").fetch(name).fetch("data")
end

def json_included
  Array(json["included"])
end

def expect_sets_csrf_cookie!
  # Your controller mints a CSRF cookie on index/show/my_events via after_action.
  set_cookie = response.headers["Set-Cookie"].to_s
  expect(set_cookie).to match(/CSRF-TOKEN=/)
end

RSpec.describe "Events", type: :request do
  let!(:amigo) { create(:amigo) }

  # Prevent network calls from EventLocation callbacks during request specs.
  before do
    ensure_stub = lambda do |klass, method_name, return_value = nil|
      if klass.instance_methods.include?(method_name)
        allow_any_instance_of(klass).to receive(method_name).and_return(return_value)
      end
    end

    # Your GeocodableWithFallback plan referenced these names:
    ensure_stub.call(EventLocation, :fetch_geocoded_data, true)
    ensure_stub.call(EventLocation, :fetch_time_zone, nil)

    # If your current implementation still uses older callback names:
    ensure_stub.call(EventLocation, :geocode_with_fallback, true)

    # Defensive: block any remote image fetches
    allow(URI).to receive(:open).and_raise("Network calls are disabled in request specs")
  end

  # -----------------------------------------------------------------------------
  # GET /api/v1/events (public)
  # -----------------------------------------------------------------------------
  describe "GET /api/v1/events" do
    it "returns ok without a token (public index)" do
      create(:event, lead_coordinator: amigo)

      get "/api/v1/events", as: :json

      expect(response).to have_http_status(:ok)
      expect_sets_csrf_cookie!

      expect(json_data).to be_an(Array)
      first = json_data.first
      expect(first).to include("id", "type", "attributes")
      expect(json_type(first)).to eq("events")
      expect(json_attrs(first)).to include("event-name", "event-date", "event-time", "status")
    end

    it "returns ok with a valid bearer token as well" do
      create(:event, lead_coordinator: amigo)

      get "/api/v1/events", headers: auth_get_headers_for(amigo), as: :json

      expect(response).to have_http_status(:ok)
      expect_sets_csrf_cookie!

      expect(json_data).to be_an(Array)
      first = json_data.first
      expect(first).to include("id", "type", "attributes")
      expect(json_type(first)).to eq("events")
      expect(json_attrs(first)).to include("event-name")
    end
  end

  # -----------------------------------------------------------------------------
  # GET /api/v1/events/:id (public)
  # -----------------------------------------------------------------------------
  describe "GET /api/v1/events/:id" do
    it "returns ok without a token (public show) and includes relationships" do
      event = create(:event, lead_coordinator: amigo)

      get "/api/v1/events/#{event.id}", as: :json

      expect(response).to have_http_status(:ok)
      expect_sets_csrf_cookie!

      resource = json_data
      expect(resource).to include("id", "type", "attributes")
      expect(json_type(resource)).to eq("events")
      expect(json_id(resource)).to eq(event.id)

      attrs = json_attrs(resource)
      expect(attrs.fetch("event-name")).to eq(event.event_name)

      # Controller uses `include: [:primary_event_location]` and serializer emits relationships.
      expect(resource).to include("relationships")
      expect(resource.fetch("relationships")).to include("lead-coordinator", "primary-event-location")
    end

    it "returns ok with a valid bearer token as well" do
      event = create(:event, lead_coordinator: amigo)

      get "/api/v1/events/#{event.id}", headers: auth_get_headers_for(amigo), as: :json

      expect(response).to have_http_status(:ok)

      resource = json_data
      expect(json_type(resource)).to eq("events")
      expect(json_id(resource)).to eq(event.id)
      expect(json_attrs(resource).fetch("event-name")).to eq(event.event_name)
    end
  end

  # -----------------------------------------------------------------------------
  # POST /api/v1/events (protected + CSRF)
  # -----------------------------------------------------------------------------
  describe "POST /api/v1/events" do
    it "creates an event with CSRF (and creates lead connector + primary location)" do
      payload = {
        event: {
          event_name: "RSPEC Event",
          event_type: "Meetup",
          event_date: Date.current.to_s,
          event_time: "18:00",
          status: "planning",
          description: "hello",
          event_speakers_performers: ["Alice", " Bob ", ""],
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
      }

      post "/api/v1/events",
           params: payload,
           headers: auth_headers_for(amigo), # JWT + CSRF
           as: :json

      expect(response).to have_http_status(:created)

      resource = json_data
      created_id = json_id(resource)

      created = Event.find(created_id)
      expect(created.lead_coordinator_id).to eq(amigo.id)
      expect(created.event_amigo_connectors.lead_coordinator.count).to eq(1)

      # normalization behavior from Event#normalize_event_speakers
      expect(created.event_speakers_performers).to eq(["Alice", "Bob"])

      # Location was provided, so primary location should exist
      expect(created.primary_event_location).to be_present

      # JSON:API contract: relationship exists and included may contain the location
      expect(resource.fetch("relationships")).to include("primary-event-location")

      # If included is present, ensure it contains an event-locations resource
      inc = json_included
      if inc.any?
        expect(inc.any? { |r| r["type"] == "event-locations" }).to be(true)
      end
    end

    it "returns unauthorized without CSRF" do
      post "/api/v1/events",
           params: { event: { event_name: "No CSRF" } },
           headers: auth_get_headers_for(amigo), # JWT only (no CSRF)
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json.fetch("error")).to be_present
    end
  end

  # -----------------------------------------------------------------------------
  # PATCH /api/v1/events/:id (protected + CSRF)
  # -----------------------------------------------------------------------------
  describe "PATCH /api/v1/events/:id" do
    it "rejects update when actor is not lead/admin/assistant" do
      lead = create(:amigo)
      event = create(:event, lead_coordinator: lead)
      create(:event_amigo_connector, :lead, event: event, amigo: lead)

      outsider = create(:amigo)

      patch "/api/v1/events/#{event.id}",
            params: { event: { description: "nope" } },
            headers: auth_headers_for(outsider),
            as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "updates core fields with CSRF when actor is lead" do
      event = create(:event, lead_coordinator: amigo)
      create(:event_amigo_connector, :lead, event: event, amigo: amigo)

      patch "/api/v1/events/#{event.id}",
            params: { event: { description: "Updated description" } },
            headers: auth_headers_for(amigo),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(event.reload.description).to eq("Updated description")

      resource = json_data
      expect(json_id(resource)).to eq(event.id)
      expect(json_attrs(resource).fetch("description")).to eq("Updated description")
    end

    it "upserts primary location when location attrs are present" do
      event = create(:event, lead_coordinator: amigo)
      create(:event_amigo_connector, :lead, event: event, amigo: amigo)

      patch "/api/v1/events/#{event.id}",
            params: {
              event: {
                description: "Updated",
                location: {
                  business_name: "Updated Venue",
                  street_name: "Main",
                  city: "Springfield",
                  has_food: false,
                  search_criteria: ["cozy", "quiet"],
                  search_venue_types: ["coffee_shop"]
                }
              }
            },
            headers: auth_headers_for(amigo),
            as: :json

      expect(response).to have_http_status(:ok)

      event.reload
      expect(event.primary_event_location).to be_present
      expect(event.primary_event_location.business_name).to eq("Updated Venue")
      expect(event.primary_event_location.search_criteria).to eq(["cozy", "quiet"])
      expect(event.primary_event_location.search_venue_types).to eq(["coffee_shop"])

      resource = json_data
      expect(resource.fetch("relationships")).to include("primary-event-location")

      # If included exists, the primary location should appear there
      inc = json_included
      if inc.any?
        loc = inc.find { |r| r["type"] == "event-locations" }
        expect(loc).to be_present
        expect(loc.fetch("attributes").fetch("business-name")).to eq("Updated Venue")
        expect(loc.fetch("attributes").fetch("search-criteria")).to eq(["cozy", "quiet"])
        expect(loc.fetch("attributes").fetch("search-venue-types")).to eq(["coffee_shop"])
      end
    end
  end

  # -----------------------------------------------------------------------------
  # DELETE /api/v1/events/:id (protected + CSRF)
  # -----------------------------------------------------------------------------
  describe "DELETE /api/v1/events/:id" do
    it "rejects destroy when actor is assistant (not lead/admin)" do
      lead = create(:amigo)
      assistant = create(:amigo)
      event = create(:event, lead_coordinator: lead)
      create(:event_amigo_connector, :lead, event: event, amigo: lead)
      create(:event_amigo_connector, :assistant, event: event, amigo: assistant)

      delete "/api/v1/events/#{event.id}",
             headers: auth_headers_for(assistant),
             as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "destroys when actor is lead" do
      event = create(:event, lead_coordinator: amigo)
      create(:event_amigo_connector, :lead, event: event, amigo: amigo)

      delete "/api/v1/events/#{event.id}",
             headers: auth_headers_for(amigo),
             as: :json

      expect(response).to have_http_status(:ok)
      expect(Event.where(id: event.id)).to be_empty
    end
  end

  # -----------------------------------------------------------------------------
  # GET /api/v1/events/my_events (protected)
  # -----------------------------------------------------------------------------
  describe "GET /api/v1/events/my_events" do
    it "returns only events the current amigo manages (lead or assistant)" do
      lead_event = create(:event, lead_coordinator: amigo)
      create(:event_amigo_connector, :lead, event: lead_event, amigo: amigo)

      other_event = create(:event) # lead_coordinator is someone else (factory)
      create(:event_amigo_connector, :assistant, event: other_event, amigo: amigo)

      not_mine = create(:event)

      get "/api/v1/events/my_events", headers: auth_get_headers_for(amigo), as: :json

      expect(response).to have_http_status(:ok)
      expect_sets_csrf_cookie!

      expect(json_data).to be_an(Array)

      ids = json_data.map { |resource| json_id(resource) }

      expect(ids).to include(lead_event.id, other_event.id)
      expect(ids).not_to include(not_mine.id)
    end

    it "returns unauthorized without a token" do
      get "/api/v1/events/my_events", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
