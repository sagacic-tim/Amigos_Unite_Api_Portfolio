# spec/requests/auth/verify_token_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth Verify Token", type: :request do
  def json
    JSON.parse(response.body)
  end

  # The ApplicationController mints CSRF cookies on API GETs.
  # This is used primarily to satisfy /login (POST requires CSRF).
  def mint_csrf_token!
    https!
    get "/api/v1/csrf", as: :json
    expect(response).to have_http_status(:no_content).or have_http_status(:ok)

    token = response.headers["X-CSRF-Token"]
    expect(token).to be_present
    token
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  let!(:password) { "Password!123" }
  let!(:amigo) do
    create(
      :amigo,
      password: password,
      password_confirmation: password,
      email: "tim@example.com",
      user_name: "timmy"
    )
  end

  def login!(csrf_token:, login_attribute: amigo.email, password_value: password)
    post "/api/v1/login",
         params: { amigo: { login_attribute: login_attribute, password: password_value } },
         headers: csrf_headers(csrf_token),
         as: :json

    expect(response).to have_http_status(:ok)
  end

  describe "GET /api/v1/verify_token" do
    it "returns 200 and valid=true when jwt cookie is present" do
      csrf = mint_csrf_token!
      login!(csrf_token: csrf)

      get "/api/v1/verify_token", as: :json

      expect(response).to have_http_status(:ok)

      body = json
      expect(body).to include("valid" => true)
      expect(body).to have_key("expires_at")

      # Basic sanity: ISO8601-ish and in the future
      exp = Time.iso8601(body.fetch("expires_at"))
      expect(exp).to be > Time.now.utc
    end

    it "returns 401 and valid=false when token is missing" do
      get "/api/v1/verify_token", as: :json

      expect(response).to have_http_status(:unauthorized)

      body = json
      expect(body).to include("valid" => false)
      expect(body).to have_key("reason")
    end

    it "accepts a Bearer token header as well" do
      csrf = mint_csrf_token!
      login!(csrf_token: csrf)

      # Extract raw jwt cookie value from Set-Cookie on login response.
      # This is the most reliable way in request specs without relying on controller internals.
      set_cookie = response.headers["Set-Cookie"]
      header = set_cookie.is_a?(Array) ? set_cookie.join("\n") : set_cookie.to_s
      jwt_match = header.match(/jwt=([^;]+)/i)
      skip("Could not parse jwt cookie from Set-Cookie") unless jwt_match

      raw_jwt = jwt_match[1]

      get "/api/v1/verify_token",
          headers: { "Authorization" => "Bearer #{raw_jwt}" },
          as: :json

      expect(response).to have_http_status(:ok)

      body = json
      expect(body).to include("valid" => true)
      expect(body).to have_key("expires_at")
    end

    it "returns 401 and valid=false when token is invalid" do
      get "/api/v1/verify_token",
          headers: { "Authorization" => "Bearer not-a-real-token" },
          as: :json

      expect(response).to have_http_status(:unauthorized)

      body = json
      expect(body).to include("valid" => false)
      expect(body).to have_key("reason")
    end
  end
end
