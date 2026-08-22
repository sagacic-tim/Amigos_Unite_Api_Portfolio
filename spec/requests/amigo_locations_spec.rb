# spec/requests/amigo_locations_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AmigoLocations", type: :request do
  let!(:amigo) { create(:amigo) }
  let!(:loc)   { create(:amigo_location, amigo: amigo) }

  def base_path
    "/api/v1/amigos/#{amigo.id}/amigo_locations"
  end

  describe "GET /api/v1/amigos/:amigo_id/amigo_locations" do
    it "returns ok and an array-ish payload" do
      get base_path, headers: auth_get_headers_for(amigo), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(loc.address)
    end
  end

  describe "POST /api/v1/amigos/:amigo_id/amigo_locations" do
    it "creates with CSRF" do
      post base_path,
           params: { amigo_location: { address: "500 Market St, San Francisco, CA" } },
           headers: auth_headers_for(amigo),
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.body).to include("500 Market")
    end

    it "rejects without CSRF" do
      post base_path,
           params: { amigo_location: { address: "500 Market St, San Francisco, CA" } },
           headers: auth_get_headers_for(amigo).merge("CONTENT_TYPE" => "application/json"),
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/amigos/:amigo_id/amigo_locations/:id" do
    it "updates with CSRF" do
      patch "#{base_path}/#{loc.id}",
            params: { amigo_location: { address: "Updated Address" } },
            headers: auth_headers_for(amigo),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(loc.reload.address).to include("Updated")
    end
  end

  describe "DELETE /api/v1/amigos/:amigo_id/amigo_locations/:id" do
    it "deletes with CSRF" do
      delete "#{base_path}/#{loc.id}",
             headers: auth_headers_for(amigo),
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(AmigoLocation.find_by(id: loc.id)).to be_nil
    end
  end
end
