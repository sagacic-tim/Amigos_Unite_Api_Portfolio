
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "EventLocationConnectors", type: :request do
  let!(:lead)  { create(:amigo) }
  let!(:event) { create(:event, lead_coordinator: lead) }

  before do
    create(:event_amigo_connector, :lead, event: event, amigo: lead)
    allow_any_instance_of(EventLocation).to receive(:geocode_with_fallback)
    allow_any_instance_of(EventLocation).to receive(:fetch_time_zone)
  end

  describe "POST /api/v1/events/:event_id/event_location_connectors" do
    it "creates connector and sets primary when requested" do
      loc = create(:event_location)

      post "/api/v1/events/#{event.id}/event_location_connectors",
           params: { event_location_connector: { event_location_id: loc.id, is_primary: true } },
           headers: auth_headers_for(lead),
           as: :json

      expect(response).to have_http_status(:created).or have_http_status(:ok)
      connector = EventLocationConnector.find_by(event_id: event.id, event_location_id: loc.id)
      expect(connector).to be_present
      expect(connector.is_primary).to eq(true)
    end
  end

  describe "PATCH /api/v1/events/:event_id/event_location_connectors/:id" do
    it "flips primary to another connector" do
      loc1 = create(:event_location)
      loc2 = create(:event_location)

      c1 = create(:event_location_connector, :primary, event: event, event_location: loc1)
      c2 = create(:event_location_connector, event: event, event_location: loc2)

      patch "/api/v1/events/#{event.id}/event_location_connectors/#{c2.id}",
            params: { event_location_connector: { is_primary: true } },
            headers: auth_headers_for(lead),
            as: :json

      expect(response).to have_http_status(:ok)

      expect(c1.reload.is_primary).to eq(false)
      expect(c2.reload.is_primary).to eq(true)
    end
  end

  describe "DELETE /api/v1/events/:event_id/event_location_connectors/:id" do
    it "deletes connector when authorized" do
      loc = create(:event_location)
      c = create(:event_location_connector, event: event, event_location: loc)

      delete "/api/v1/events/#{event.id}/event_location_connectors/#{c.id}",
             headers: auth_headers_for(lead),
             as: :json

      expect(response).to have_http_status(:ok)
      expect(EventLocationConnector.where(id: c.id)).to be_empty
    end
  end
end
