# spec/services/google_places/agentic_location_search_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe GooglePlaces::AgenticLocationSearch, type: :service do
  def build_service
    described_class.new(
      lat: 37.0, lng: -122.0, city: "Springfield", state_province: "Missouri",
      criteria: ["cool vibes"], api_key: "test-key"
    )
  end

  def api_error(klass, status:, message:)
    klass.new(url: URI("https://api.anthropic.com/v1/messages"), status: status,
              headers: {}, body: { error: { message: message } }, request: nil, response: nil,
              message: message)
  end

  it "logs a distinct, greppable message and returns [] when credits are exhausted" do
    service = build_service
    error = api_error(Anthropic::Errors::BadRequestError, status: 400,
                       message: "Your credit balance is too low to access the Anthropic API.")
    allow(service).to receive(:run_agentic_loop).and_raise(error)

    expect(Rails.logger).to receive(:error).with(/ANTHROPIC_BILLING_ERROR/)

    expect(service.call).to eq([])
  end

  it "logs a generic API error message (not the billing one) for unrelated 400s" do
    service = build_service
    error = api_error(Anthropic::Errors::BadRequestError, status: 400, message: "model not found")
    allow(service).to receive(:run_agentic_loop).and_raise(error)

    expect(Rails.logger).to receive(:error).with(/Anthropic API error/).and_call_original
    expect(Rails.logger).not_to receive(:error).with(/ANTHROPIC_BILLING_ERROR/)

    expect(service.call).to eq([])
  end

  it "still returns [] for other Anthropic API errors, e.g. rate limits" do
    service = build_service
    error = api_error(Anthropic::Errors::RateLimitError, status: 429, message: "rate limited")
    allow(service).to receive(:run_agentic_loop).and_raise(error)

    expect(service.call).to eq([])
  end

  describe "radius enforcement" do
    let(:base_radius) { described_class::RADIUS_METRES }
    let(:expanded_radius) { described_class::RADIUS_METRES + described_class::RADIUS_EXPANSION_METRES }

    it "accepts venues within the base 5-mile radius" do
      service = build_service
      expect(service.send(:out_of_radius?, 37.03, -122.0, base_radius)).to be false
    end

    it "rejects venues far outside the radius (e.g. ~20 miles away)" do
      service = build_service
      expect(service.send(:out_of_radius?, 37.29, -122.0, base_radius)).to be true
    end

    it "rejects venues with missing coordinates" do
      service = build_service
      expect(service.send(:out_of_radius?, nil, nil, base_radius)).to be true
    end

    it "widens the radius once the eligible pool is thinner than MIN_ELIGIBLE_VENUES" do
      service = build_service
      cache = service.instance_variable_get(:@coords_cache)
      3.times { |i| cache["place_#{i}"] = { lat: 37.0, lng: -122.0 } }

      service.send(:maybe_expand_radius!)

      expect(service.instance_variable_get(:@effective_radius_metres)).to eq(expanded_radius)
    end

    it "keeps the base radius once enough eligible venues have been found" do
      service = build_service
      cache = service.instance_variable_get(:@coords_cache)
      described_class::MIN_ELIGIBLE_VENUES.times { |i| cache["place_#{i}"] = { lat: 37.0, lng: -122.0 } }

      service.send(:maybe_expand_radius!)

      expect(service.instance_variable_get(:@effective_radius_metres)).to eq(base_radius)
    end

    it "filters out-of-radius candidates before caching, and widens radius when the pool stays thin" do
      service = build_service
      near = { place_id: "near1", name: "Near Cafe", formatted_address: "123 Near St",
                rating: 4.5, types: ["cafe"], lat: 37.03, lng: -122.0 }
      far  = { place_id: "far1", name: "Far Cafe", formatted_address: "999 Far St",
                rating: 4.9, types: ["cafe"], lat: 37.29, lng: -122.0 }

      fake_client = instance_double(
        GooglePlaces::Client,
        text_search_near: [near, far, near.merge(place_id: "near2"), near.merge(place_id: "near3")]
      )
      allow(service).to receive(:places_client).and_return(fake_client)

      result = service.send(:dispatch_tool, "search_venues", { "query" => "cafe" })

      ids = result.map { |r| r[:place_id] }
      expect(ids).to include("near1", "near2", "near3")
      expect(ids).not_to include("far1")

      # Only 3 eligible venues found — below MIN_ELIGIBLE_VENUES(4) — so the
      # next search_venues call should use the widened radius.
      expect(service.instance_variable_get(:@effective_radius_metres)).to eq(expanded_radius)
    end
  end
end
