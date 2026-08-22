# spec/requests/auth/sessions_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth Sessions", type: :request do
  def json
    JSON.parse(response.body)
  end

  def set_cookie_header
    raw = response.headers["Set-Cookie"]
    raw.is_a?(Array) ? raw.join("\n") : raw.to_s
  end

  def expect_cookie_set!(name)
    expect(set_cookie_header).to include("#{name}=")
  end

  def expect_cookie_cleared!(name)
    expect(set_cookie_header).to match(/#{Regexp.escape(name)}=;?/i)
    expect(set_cookie_header).to match(/expires=|max-age=0/i)
  end

  # For endpoints that may not emit a Set-Cookie for a cookie that wasn't present.
  def expect_cookie_cleared_or_absent!(name)
    header = set_cookie_header
    return if header.blank?

    if header.match?(/#{Regexp.escape(name)}=/i)
      expect(header).to match(/#{Regexp.escape(name)}=;?/i)
      expect(header).to match(/expires=|max-age=0/i)
    end
  end

  # The global ApplicationController requires CSRF for *all* POST/PUT/PATCH/DELETE,
  # including /login and /logout. This primes the cookie + returns a header token
  # that matches the cookie.
  def mint_csrf_token!
    https!

    get "/api/v1/csrf", as: :json

    # The CsrfController currently returns 204 (head :no_content).
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

  describe "POST /api/v1/login" do
    it "returns 200, sets JWT + CSRF cookies, and returns amigo payload" do
      csrf = mint_csrf_token!

      post "/api/v1/login",
           params: {
             amigo: {
               login_attribute: amigo.email,
               password: password
             }
           },
           headers: csrf_headers(csrf),
           as: :json

      expect(response).to have_http_status(:ok)

      body = json
      expect(body.fetch("status")).to include("code" => 200)
      expect(body.fetch("data")).to include("amigo", "jwt_expires_at")

      amigo_payload = body.fetch("data").fetch("amigo")
      expect(amigo_payload).to include(
        "id" => amigo.id,
        "user_name" => amigo.user_name,
        "email" => amigo.email
      )

      # Cookies
      expect_cookie_set!("jwt")
      expect_cookie_set!("CSRF-TOKEN")

      # JWT cookie flags
      expect(set_cookie_header).to match(/jwt=.*HttpOnly/i)
      expect(set_cookie_header).to match(/jwt=.*Secure/i)
      expect(set_cookie_header).to match(/jwt=.*SameSite=None/i)
      expect(set_cookie_header).to match(/jwt=.*Path=\//i)

      # CSRF cookie flags (in SessionsController#create you set SameSite strict in test env)
      expect(set_cookie_header).to match(/CSRF-TOKEN=.*Secure/i)
      expect(set_cookie_header).to match(/CSRF-TOKEN=.*Path=\//i)
      expect(set_cookie_header).to match(/CSRF-TOKEN=.*SameSite=Strict/i)
    end

    it "accepts login_attribute as user_name as well" do
      csrf = mint_csrf_token!

      post "/api/v1/login",
           params: {
             amigo: {
               login_attribute: amigo.user_name,
               password: password
             }
           },
           headers: csrf_headers(csrf),
           as: :json

      expect(response).to have_http_status(:ok)
      expect_cookie_set!("jwt")
    end

    it "returns 401 for invalid credentials with stable JSON shape" do
      csrf = mint_csrf_token!

      post "/api/v1/login",
           params: {
             amigo: {
               login_attribute: amigo.email,
               password: "wrong-password"
             }
           },
           headers: csrf_headers(csrf),
           as: :json

      expect(response).to have_http_status(:unauthorized)

      body = json
      expect(body.fetch("status")).to include("code" => 401)
      expect(body.fetch("errors")).to be_an(Array)

      # Should not mint a JWT cookie on failure
      expect(set_cookie_header).not_to include("jwt=")
    end
  end

  describe "DELETE /api/v1/logout" do
    it "returns 204 and clears cookies (even if already signed out)" do
      csrf = mint_csrf_token!

      delete "/api/v1/logout",
             headers: csrf_headers(csrf),
             as: :json

      expect(response).to have_http_status(:no_content)

      # Always cleared by controller
      expect_cookie_cleared!("CSRF-TOKEN")

      # May be absent if no jwt cookie existed
      expect_cookie_cleared_or_absent!("jwt")
    end

    it "returns 204 and clears cookies after a successful login" do
      csrf = mint_csrf_token!

      post "/api/v1/login",
           params: { amigo: { login_attribute: amigo.email, password: password } },
           headers: csrf_headers(csrf),
           as: :json
      expect(response).to have_http_status(:ok)
      expect_cookie_set!("jwt")

      # Login rotates CSRF cookie; mint a fresh CSRF token so header matches cookie.
      csrf2 = mint_csrf_token!

      delete "/api/v1/logout",
             headers: csrf_headers(csrf2),
             as: :json

      expect(response).to have_http_status(:no_content)

      expect_cookie_cleared!("jwt")
      expect_cookie_cleared!("CSRF-TOKEN")
    end
  end
end
