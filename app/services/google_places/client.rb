# app/services/google_places/client.rb
require "net/http"
require "uri"
require "json"

module GooglePlaces
  class Client
    TEXT_SEARCH_URL   = "https://maps.googleapis.com/maps/api/place/textsearch/json".freeze
    NEARBY_SEARCH_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json".freeze
    DETAILS_URL       = "https://maps.googleapis.com/maps/api/place/details/json".freeze
    PHOTO_BASE_URL    = "https://maps.googleapis.com/maps/api/place/photo".freeze
    GEOCODE_URL       = "https://maps.googleapis.com/maps/api/geocode/json".freeze

    MAX_PLACES           = 5
    MAX_PHOTOS_PER_PLACE = 10

    def initialize(api_key: ENV["GOOGLE_MAPS_API_KEY"].presence || Rails.application.credentials.dig(:google_maps, :api_key))
      @api_key = api_key.to_s
      raise Error.new("Google Places API key missing", http_code: 500) if @api_key.blank?
    end

    # ------------------------------------------------------------------------
    # 1) Light-weight place search (map-friendly)
    # ------------------------------------------------------------------------
    def search_places(query, max_results: MAX_PLACES, type: nil)
      q = query.to_s.strip
      return [] if q.blank?

      uri = URI(TEXT_SEARCH_URL)
      params = {
        key:   @api_key,
        query: q,
        type:  type.presence
      }.compact
      uri.query = URI.encode_www_form(params)

      json = get_json_hash(uri, context: "textsearch")

      google_status = json["status"].to_s
      if google_status != "OK" && google_status != "ZERO_RESULTS"
        msg = json["error_message"].presence || "Google Places text search failed"
        raise Error.new(msg, http_code: 502, google_status: google_status)
      end

      results = Array(json["results"]).first(max_results.to_i)

      results.map do |place|
        # Defensive: ensure each element is a Hash; otherwise skip it.
        next unless place.is_a?(Hash)

        geometry = place["geometry"].is_a?(Hash) ? place["geometry"] : {}
        location = geometry["location"].is_a?(Hash) ? geometry["location"] : {}

        photo0 = Array(place["photos"]).first
        primary_ref =
          photo0.is_a?(Hash) ? photo0["photo_reference"] : nil

        {
          place_id:               place["place_id"],
          name:                   place["name"],
          formatted_address:      place["formatted_address"],
          lat:                    location["lat"],
          lng:                    location["lng"],
          primary_photo_reference: primary_ref
        }
      end.compact
    end

    # ------------------------------------------------------------------------
    # 2) Nearby search — requires lat/lng centre + radius in metres
    # ------------------------------------------------------------------------
    def nearby_search(lat:, lng:, radius_metres: 8047, keyword: nil, type: nil, max_results: 10)
      uri = URI(NEARBY_SEARCH_URL)
      params = {
        key:      @api_key,
        location: "#{lat},#{lng}",
        radius:   radius_metres.to_i,
        keyword:  keyword.presence,
        type:     type.presence
      }.compact
      uri.query = URI.encode_www_form(params)

      json = get_json_hash(uri, context: "nearbysearch")

      google_status = json["status"].to_s
      if google_status != "OK" && google_status != "ZERO_RESULTS"
        msg = json["error_message"].presence || "Google Places nearby search failed"
        raise Error.new(msg, http_code: 502, google_status: google_status)
      end

      results = Array(json["results"]).first(max_results.to_i)

      results.map do |place|
        next unless place.is_a?(Hash)

        geometry = place["geometry"].is_a?(Hash) ? place["geometry"] : {}
        location = geometry["location"].is_a?(Hash) ? geometry["location"] : {}
        photo0   = Array(place["photos"]).first
        primary_ref = photo0.is_a?(Hash) ? photo0["photo_reference"] : nil

        {
          place_id:                place["place_id"],
          name:                    place["name"],
          formatted_address:       place["vicinity"].presence || place["formatted_address"],
          lat:                     location["lat"],
          lng:                     location["lng"],
          types:                   Array(place["types"]),
          rating:                  place["rating"],
          primary_photo_reference: primary_ref
        }
      end.compact
    end

    # ------------------------------------------------------------------------
    # 3) Text search with location bias — better semantic matching than
    #    nearby_search for intent-based queries like
    #    "jazz cafe with indoor seating near downtown".
    #    Uses the Places Text Search endpoint with a location + radius bias.
    # ------------------------------------------------------------------------
    def text_search_near(query:, lat:, lng:, radius_metres: 8047, type: nil, max_results: 10)
      q = query.to_s.strip
      return [] if q.blank?

      uri = URI(TEXT_SEARCH_URL)
      params = {
        key:      @api_key,
        query:    q,
        location: "#{lat},#{lng}",
        radius:   radius_metres.to_i,
        type:     type.presence
      }.compact
      uri.query = URI.encode_www_form(params)

      json = get_json_hash(uri, context: "textsearch_near")

      google_status = json["status"].to_s
      if google_status != "OK" && google_status != "ZERO_RESULTS"
        msg = json["error_message"].presence || "Google Places text search failed"
        raise Error.new(msg, http_code: 502, google_status: google_status)
      end

      results = Array(json["results"]).first(max_results.to_i)

      results.map do |place|
        next unless place.is_a?(Hash)

        geometry = place["geometry"].is_a?(Hash) ? place["geometry"] : {}
        location = geometry["location"].is_a?(Hash) ? geometry["location"] : {}
        photo0   = Array(place["photos"]).first
        primary_ref = photo0.is_a?(Hash) ? photo0["photo_reference"] : nil

        {
          place_id:                place["place_id"],
          name:                    place["name"],
          formatted_address:       place["formatted_address"],
          lat:                     location["lat"],
          lng:                     location["lng"],
          types:                   Array(place["types"]),
          rating:                  place["rating"],
          primary_photo_reference: primary_ref
        }
      end.compact
    end

    # ------------------------------------------------------------------------
    # 4) Geocode a free-text address → { lat:, lng: }  (returns nil on miss)
    # ------------------------------------------------------------------------
    def geocode(address)
      addr = address.to_s.strip
      return nil if addr.blank?

      uri = URI(GEOCODE_URL)
      uri.query = URI.encode_www_form(key: @api_key, address: addr)

      json = get_json_hash(uri, context: "geocode")

      google_status = json["status"].to_s
      return nil unless google_status == "OK"

      result   = Array(json["results"]).first
      return nil unless result.is_a?(Hash)

      loc = result.dig("geometry", "location")
      return nil unless loc.is_a?(Hash)

      { lat: loc["lat"], lng: loc["lng"] }
    end

    # ------------------------------------------------------------------------
    # 5) Fetch structured address components for a single place_id.
    #    Returns a flat hash ready to be sent to the frontend so Step 6 of
    #    the EventForm can pre-fill postal_code, postal_code_suffix,
    #    state_province_short, country_short, etc. that the Nearby Search
    #    "vicinity" string doesn't include.
    # ------------------------------------------------------------------------
    def address_for_place(place_id)
      pid = place_id.to_s.strip
      return {} if pid.blank?

      uri = URI(DETAILS_URL)
      params = {
        key:      @api_key,
        place_id: pid,
        fields:   "address_components"
      }
      uri.query = URI.encode_www_form(params)

      json = get_json_hash(uri, context: "details/address")

      google_status = json["status"].to_s
      if google_status != "OK"
        msg = json["error_message"].presence || "Google Places details lookup failed"
        raise Error.new(msg, http_code: 502, google_status: google_status)
      end

      result     = json["result"].is_a?(Hash) ? json["result"] : {}
      components = Array(result["address_components"])

      # Map Google address_component types → our field names.
      # Each entry is [ long_name_key, short_name_key ] (nil = not used).
      mappings = {
        "street_number"               => [:street_number,      nil],
        "route"                       => [:street_name,        :street_name_short],
        "locality"                    => [:city,               nil],
        "administrative_area_level_1" => [:state_province,     :state_province_short],
        "country"                     => [:country,            :country_short],
        "postal_code"                 => [:postal_code,        nil],
        "postal_code_suffix"          => [:postal_code_suffix, nil],
      }

      out = {}
      components.each do |component|
        type    = Array(component["types"]).first
        mapping = mappings[type]
        next unless mapping

        long_key, short_key = mapping
        out[long_key]  = component["long_name"]  if long_key
        out[short_key] = component["short_name"] if short_key
      end

      out
    end

    # ------------------------------------------------------------------------
    # 6) Fetch up to 10 photos for a single place_id
    # ------------------------------------------------------------------------
    def photos_for_place(place_id, max_photos: MAX_PHOTOS_PER_PLACE, max_width: 640)
      pid = place_id.to_s.strip
      return [] if pid.blank?

      uri = URI(DETAILS_URL)
      params = {
        key:      @api_key,
        place_id: pid,
        fields:   "photos"
      }
      uri.query = URI.encode_www_form(params)

      json = get_json_hash(uri, context: "details")

      google_status = json["status"].to_s
      if google_status != "OK"
        msg = json["error_message"].presence || "Google Places details lookup failed"
        # NOT_FOUND / INVALID_REQUEST / REQUEST_DENIED etc.
        raise Error.new(msg, http_code: 502, google_status: google_status)
      end

      result = json["result"].is_a?(Hash) ? json["result"] : {}
      photos = Array(result["photos"]).first(max_photos.to_i)

      photos.map do |photo|
        next unless photo.is_a?(Hash)

        ref = photo["photo_reference"].to_s
        next if ref.blank?

        attributions = Array(photo["html_attributions"]).compact
        attribution_str = attributions.join(", ")

        {
          place_id:          pid,
          photo_reference:   ref,
          photo_url:         build_photo_url(ref, max_width: max_width),
          photo_attribution: attribution_str
        }
      end.compact
    end

    private

    # Ensures we always return a Hash; never a String/Array/etc.
    def get_json_hash(uri, context:)
      res = Net::HTTP.get_response(uri)

      unless res.is_a?(Net::HTTPSuccess)
        # Do not log the full URI because it contains the API key in query params.
        Rails.logger.error("[GooglePlaces::Client] #{context} HTTP #{res.code}")
        raise Error.new("Google Places upstream HTTP #{res.code}", http_code: 502)
      end

      raw = res.body.to_s
      parsed = JSON.parse(raw)

      unless parsed.is_a?(Hash)
        Rails.logger.error("[GooglePlaces::Client] #{context} unexpected JSON root=#{parsed.class}")
        raise Error.new("Google Places returned unexpected payload shape", http_code: 502)
      end

      parsed
    rescue JSON::ParserError => e
      Rails.logger.error("[GooglePlaces::Client] #{context} JSON parse error: #{e.message}")
      raise Error.new("Google Places returned invalid JSON", http_code: 502)
    rescue Error
      raise
    rescue StandardError => e
      Rails.logger.error("[GooglePlaces::Client] #{context} request failed: #{e.class}: #{e.message}")
      raise Error.new("Google Places request failed", http_code: 502)
    end

    def build_photo_url(photo_reference, max_width: 640)
      params = {
        key:            @api_key,
        photoreference: photo_reference,
        maxwidth:       max_width.to_i
      }
      "#{PHOTO_BASE_URL}?#{URI.encode_www_form(params)}"
    end
  end
end
