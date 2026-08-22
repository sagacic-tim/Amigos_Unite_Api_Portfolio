# config/initializers/geocoder.rb
# frozen_string_literal: true

# Safely resolve the Google Maps API key from ENV or credentials
def google_maps_api_key
  # 1) Prefer an ENV variable if present (useful for CI/production)
  env_key = ENV["GOOGLE_MAPS_API_KEY"]
  return env_key if env_key && !env_key.empty?

  creds = Rails.application.credentials
  return nil unless creds.respond_to?(:[])

  google_maps = creds[:google_maps] || creds["google_maps"]

  case google_maps
  when Hash
    google_maps[:api_key] || google_maps["api_key"]
  when String
    google_maps
  else
    nil
  end
rescue StandardError => e
  Rails.logger.warn("[Geocoder] Could not load Google Maps API key: #{e.class}: #{e.message}") if defined?(Rails)
  nil
end

Geocoder.configure(
  # Primary geocoding service
  lookup: :google,

  # Secure API key from ENV / encrypted credentials
  api_key: google_maps_api_key,

  # Automatically use HTTPS in production (Google requires HTTPS anyway)
  use_https: true,

  # Timeout for API requests in seconds
  timeout: 20,

  # Use miles for distance calculations (set to :km if needed)
  units: :mi,

  # Default language for API responses
  language: :en,

  # Enable Rails logger for debugging geocoding issues
  logger: Rails.logger,

  # Cache responses using Rails.cache (not Redis directly)
  cache: Rails.cache,
  cache_prefix: "geocoder:",

  # IP-based geolocation service
  ip_lookup: :ipinfo_io,

  # Do not raise exceptions on geocoding errors (we handle them manually)
  always_raise: [],

  # HTTPS headers (you can set referer headers here if needed for Google)
  http_headers: {}

)

# Optional manual fallback to open-source Nominatim
module GeocoderWithFallback
  def self.search_with_fallback(query, options = {})
    Geocoder.search(query, options)
  rescue => e
    Rails.logger.warn "[Geocoder Fallback] Primary lookup failed: #{e.message}"
    Geocoder.configure(lookup: :nominatim)
    result = Geocoder.search(query, options)
    Geocoder.configure(lookup: :google) # Restore default lookup
    result
  end
end
