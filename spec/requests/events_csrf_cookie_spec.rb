
# spec/requests/events_csrf_cookie_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Events CSRF cookie minting", type: :request do
  def set_cookie_header
    raw = response.headers["Set-Cookie"]
    raw.is_a?(Array) ? raw.join("\n") : raw.to_s
  end

  def expect_csrf_cookie_set!
    header = set_cookie_header
    expect(header).to be_present
    expect(header).to match(/CSRF-TOKEN=/i)
    expect(header).to match(/path=\//i)
  end

  def expect_csrf_cookie_flags_over_https!
    header = set_cookie_header

    # Your EventsController#set_csrf_cookie sets same_site: :none always,
    # and secure is driven by request.ssl? (true under https!).
    expect(header).to match(/CSRF-TOKEN=/i)
    expect(header).to match(/secure/i)
    expect(header).to match(/samesite=none/i)
  end

  describe "GET /api/v1/events" do
    it "is public (no JWT) and mints CSRF cookie" do
      https!
      create(:event)

      get "/api/v1/events", as: :json

      expect(response).to have_http_status(:ok)
      expect_csrf_cookie_set!
      expect_csrf_cookie_flags_over_https!
    end
  end

  describe "GET /api/v1/events/:id" do
    it "is public (no JWT) and mints CSRF cookie" do
      https!
      event = create(:event)

      get "/api/v1/events/#{event.id}", as: :json

      expect(response).to have_http_status(:ok)
      expect_csrf_cookie_set!
      expect_csrf_cookie_flags_over_https!
    end
  end
end
