# config/initializers/google_maps_service.rb
require "google_maps_service"

raw_google_maps = Rails.application.credentials[:google_maps]

api_key =
  case raw_google_maps
  when String
    # Old/simple form: google_maps: "API_KEY"
    raw_google_maps
  when Hash, ActiveSupport::OrderedOptions
    # Nested form: google_maps: { api_key: "API_KEY" }
    raw_google_maps[:api_key] || raw_google_maps["api_key"]
  else
    nil
  end

if api_key.present?
  GoogleMapsService.configure do |config|
    config.key               = api_key
    config.retry_timeout     = 20
    config.queries_per_second = 10
  end
else
  # Don’t crash the app; just log a warning so you know it’s misconfigured.
  Rails.logger.warn("[GoogleMapsService] google_maps api_key is missing from credentials")
end
