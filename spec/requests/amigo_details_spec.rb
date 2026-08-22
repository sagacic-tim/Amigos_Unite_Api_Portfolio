# spec/requests/amigo_details_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AmigoDetails", type: :request do
  let!(:amigo)  { create(:amigo) }
  let!(:detail) { create(:amigo_detail, amigo: amigo, personal_bio: nil) }

  def path
    "/api/v1/amigos/#{amigo.id}/amigo_detail"
  end

  describe "GET /api/v1/amigos/:amigo_id/amigo_detail" do
    it "returns ok when detail exists" do
      get path, headers: auth_get_headers_for(amigo), as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /api/v1/amigos/:amigo_id/amigo_detail" do
    it "allows clearing personal_bio to an empty string" do
      patch path,
            params: { amigo_detail: { personal_bio: "" } },
            headers: auth_headers_for(amigo),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(detail.reload.personal_bio.to_s).to eq("")
    end

    it "rejects payload that sanitizes to empty but is not blank input" do
      patch path,
            params: { amigo_detail: { personal_bio: %(<img src=x onerror=alert(1)>) } },
            headers: auth_headers_for(amigo),
            as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(detail.reload.personal_bio).to be_nil
    end

    it "sanitizes unsafe content but preserves readable text" do
      patch path,
            params: { amigo_detail: { personal_bio: %(<b>Hello</b> <img src=x onerror=alert(1)>) } },
            headers: auth_headers_for(amigo),
            as: :json

      expect(response).to have_http_status(:ok)

      bio = detail.reload.personal_bio.to_s
      expect(bio).to include("Hello")
      expect(bio).not_to include("onerror")
      expect(bio).not_to include("alert")
      expect(bio).not_to include("<script")
    end
  end
end
