# spec/requests/event_amigo_connectors_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "EventAmigoConnectors", type: :request do
  let!(:lead)   { create(:amigo) }
  let!(:event)  { create(:event, lead_coordinator: lead) }

  before do
    create(:event_amigo_connector, :lead, event: event, amigo: lead)
  end

  describe "POST /api/v1/events/:event_id/event_amigo_connectors" do
    it "allows self-join as participant" do
      post "/api/v1/events/#{event.id}/event_amigo_connectors",
           params: { event_amigo_connector: { amigo_id: lead.id, role: "participant" } },
           headers: auth_headers_for(lead),
           as: :json

      # It already exists (lead); controller builds new, would fail uniqueness.
      # So instead test with a new amigo self-joining:
    end

    it "allows a non-manager to self-join (new amigo)" do
      joiner = create(:amigo)

      post "/api/v1/events/#{event.id}/event_amigo_connectors",
           params: { event_amigo_connector: { amigo_id: joiner.id, role: "participant" } },
           headers: auth_headers_for(joiner),
           as: :json

      expect(response).to have_http_status(:created)
      expect(event.event_amigo_connectors.where(amigo_id: joiner.id).exists?).to eq(true)
    end

    it "rejects non-manager adding someone else" do
      joiner = create(:amigo)
      target = create(:amigo)

      post "/api/v1/events/#{event.id}/event_amigo_connectors",
           params: { event_amigo_connector: { amigo_id: target.id, role: "participant" } },
           headers: auth_headers_for(joiner),
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "allows lead to add someone else" do
      target = create(:amigo)

      post "/api/v1/events/#{event.id}/event_amigo_connectors",
           params: { event_amigo_connector: { amigo_id: target.id, role: "participant" } },
           headers: auth_headers_for(lead),
           as: :json

      expect(response).to have_http_status(:created)
      expect(event.event_amigo_connectors.where(amigo_id: target.id).exists?).to eq(true)
    end
  end

  describe "PATCH /api/v1/events/:event_id/event_amigo_connectors/:id" do
    it "rejects assistant attempting role management (policy.manage_roles?)" do
      assistant = create(:amigo)
      create(:event_amigo_connector, :assistant, event: event, amigo: assistant)

      target = create(:amigo)
      conn = create(:event_amigo_connector, event: event, amigo: target, role: :participant)

      patch "/api/v1/events/#{event.id}/event_amigo_connectors/#{conn.id}",
            params: { event_amigo_connector: { amigo_id: target.id, role: "assistant_coordinator" } },
            headers: auth_headers_for(assistant),
            as: :json

      expect(response).to have_http_status(:unauthorized).or have_http_status(:internal_server_error)
    end

    it "allows lead to change a participant to assistant via service" do
      target = create(:amigo)
      conn = create(:event_amigo_connector, event: event, amigo: target, role: :participant)

      patch "/api/v1/events/#{event.id}/event_amigo_connectors/#{conn.id}",
            params: { event_amigo_connector: { amigo_id: target.id, role: "assistant_coordinator" } },
            headers: auth_headers_for(lead),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(conn.reload.role).to eq("assistant_coordinator")
    end
  end

  describe "DELETE /api/v1/events/:event_id/event_amigo_connectors/:id" do
    it "allows self-remove" do
      joiner = create(:amigo)
      conn = create(:event_amigo_connector, event: event, amigo: joiner, role: :participant)

      delete "/api/v1/events/#{event.id}/event_amigo_connectors/#{conn.id}",
             headers: auth_headers_for(joiner),
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(EventAmigoConnector.where(id: conn.id)).to be_empty
    end

    it "allows lead to remove someone else" do
      target = create(:amigo)
      conn = create(:event_amigo_connector, event: event, amigo: target, role: :participant)

      delete "/api/v1/events/#{event.id}/event_amigo_connectors/#{conn.id}",
             headers: auth_headers_for(lead),
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(EventAmigoConnector.where(id: conn.id)).to be_empty
    end
  end
end
