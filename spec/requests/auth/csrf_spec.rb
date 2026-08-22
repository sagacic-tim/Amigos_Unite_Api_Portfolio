# spec/requests/auth/csrf_spec.rb
# frozen_string_literal: true

require "rails_helper"
require "cgi"

RSpec.describe "Auth CSRF", type: :request do
  def set_cookie_header
    raw = response.headers["Set-Cookie"]
    raw.is_a?(Array) ? raw.join("\n") : raw.to_s
  end

  def cookie_value(name)
    header = set_cookie_header
    return nil if header.strip.empty?

    # Match anywhere, not just line-start (headers may be folded/combined)
    m = header.match(/#{Regexp.escape(name)}=([^;]+)/)
    m ? CGI.unescape(m[1]) : nil
  end

  def expect_csrf_cookie_present!
    expect(set_cookie_header).to include("CSRF-TOKEN=")
    expect(cookie_value("CSRF-TOKEN")).to be_present
    expect(set_cookie_header).to match(/(?:^|\n|;)\s*Path=\//i)
  end

  describe "GET /api/v1/csrf" do
    it "is callable without JWT and mints a CSRF cookie" do
      get "/api/v1/csrf", as: :json

      expect(response).to have_http_status(:no_content)
      expect_csrf_cookie_present!
    end

    it "mints a secure SameSite=None CSRF cookie over HTTPS" do
      https!
      get "/api/v1/csrf", as: :json

      expect(response).to have_http_status(:no_content)
      expect_csrf_cookie_present!

      header = set_cookie_header.downcase
      expect(header).to include("samesite=none")
      expect(header).to include("secure")
    end

    it "is stable across repeated calls (always emits a CSRF cookie)" do
      get "/api/v1/csrf", as: :json
      first = cookie_value("CSRF-TOKEN")
      expect(first).to be_present

      get "/api/v1/csrf", as: :json
      second = cookie_value("CSRF-TOKEN")
      expect(second).to be_present
    end
  end
end
