# spec/requests/amigos_spec.rb

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Amigos", type: :request do
  let!(:amigo) { create(:amigo) }

  describe "GET /api/v1/amigos" do
    it "returns ok with a valid bearer token" do
      get "/api/v1/amigos", headers: auth_get_headers_for(amigo), as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["amigos"].first["first_name"]).to eq(amigo.first_name)
      expect(json["meta"]).to include("current_page", "total_count", "total_pages", "per_page")
    end

    it "returns unauthorized without a token" do
      get "/api/v1/amigos", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/amigos/:id" do
    it "returns ok with a valid bearer token" do
      get "/api/v1/amigos/#{amigo.id}", headers: auth_get_headers_for(amigo), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(amigo.user_name)
    end

    it "returns unauthorized without a token" do
      get "/api/v1/amigos/#{amigo.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/me" do
    it "returns ok with a valid bearer token" do
      get "/api/v1/me", headers: auth_get_headers_for(amigo), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(amigo.user_name)
    end

    it "returns unauthorized without a token" do
      get "/api/v1/me", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/amigos/:id" do
    it "returns unauthorized without CSRF" do
      patch "/api/v1/amigos/#{amigo.id}",
            params: { amigo: { first_name: "Updated" } },
            headers: auth_get_headers_for(amigo), # JWT only (no CSRF)
            as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "updates with CSRF" do
      patch "/api/v1/amigos/#{amigo.id}",
            params: { amigo: { first_name: "Updated" } },
            headers: auth_headers_for(amigo), # JWT + CSRF
            as: :json

      expect(response).to have_http_status(:ok)
      expect(amigo.reload.first_name).to eq("Updated")
    end
  end
end
