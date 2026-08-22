# app/models/concerns/geocodable_with_fallback.rb
module GeocodableWithFallback
  extend ActiveSupport::Concern

  included do
    # 1) Try to geocode based on the current address fields (if we don't already
    #    have coordinates), and then best-effort fetch the time zone.
    before_validation :geocode_with_fallback

    # 2) Always rebuild the printable full address from the latest fields.
    before_validation :build_full_address
  end

  private

  # ===========================================================
  # 1. Geocode the address using partial data if coords missing
  #    and then (best-effort) fetch time zone.
  # ===========================================================
  def geocode_with_fallback
    # If we already have coordinates, just ensure time_zone is filled best-effort.
    if latitude.present? && longitude.present?
      fetch_time_zone if time_zone.blank?
      return
    end

    input_address = build_input_address_for_geocoding

    if input_address.blank?
      log_geocode_warning("Insufficient data to geocode address.")
      return
    end

    Rails.logger.debug(
      "[GeocodableWithFallback] Resolving partial address for " \
      "#{self.class.name}(id=#{id || 'new'}) => #{input_address}"
    ) if Rails.env.development?

    results = GeocoderWithFallback.search_with_fallback(input_address)

    if results.present?
      save_address_components(results.first)

      # Only attempt time zone lookup if geocoding produced coordinates.
      fetch_time_zone if latitude.present? && longitude.present?
    else
      log_geocode_warning("Geocoding failed for address: #{input_address}")
    end
  rescue StandardError => e
    # Geocoding is helpful but not fatal; log and continue so the record
    # can still be persisted if other validations pass.
    log_geocode_warning("Geocoding error: #{e.class}: #{e.message}")
  end

  # ===========================================================
  # 2. Fetch time zone from Google based on coordinates
  #    (best-effort; never blocks save).
  # ===========================================================
  def fetch_time_zone
    return unless latitude.present? && longitude.present?

    # Adjust this if your credentials structure differs
    api_key = Rails.application.credentials.google_maps rescue nil
    unless api_key.present?
      log_geocode_warning("Time zone fetch skipped: missing Google Maps API key")
      return
    end

    uri = URI("https://maps.googleapis.com/maps/api/timezone/json")
    uri.query = URI.encode_www_form(
      location: "#{latitude},#{longitude}",
      timestamp: Time.now.to_i,
      key: api_key
    )

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      log_geocode_warning("Failed to fetch time zone: HTTP #{response.code}")
      return
    end

    data = JSON.parse(response.body)

    if data["status"] == "OK" && data["timeZoneId"].present?
      # This is the field you want persisted in the DB.
      self.time_zone = data["timeZoneId"]
    else
      log_geocode_warning(
        "Time zone API returned status=#{data['status'].inspect} " \
        "for lat=#{latitude}, lon=#{longitude}"
      )
    end
  rescue StandardError => e
    # IMPORTANT: Do NOT add to errors here; just log. We do not want
    # the whole save to fail because the time zone service hiccuped.
    log_geocode_warning("Time zone fetch error: #{e.class}: #{e.message}")
  end

  # ===========================================================
  # 3. Extract lat/lng and address parts into individual fields
  # ===========================================================
  def save_address_components(result)
    if (loc = result.data.dig("geometry", "location"))
      self.latitude  = loc["lat"]
      self.longitude = loc["lng"]
    end

    mappings = {
      "floor"                       => :floor,
      "room"                        => :room_no,
      "subpremise"                  => :apartment_suite_number,
      "street_number"               => :street_number,
      "route"                       => :street_name,
      "sublocality"                 => :city_sublocality,
      "locality"                    => :city,
      "administrative_area_level_2" => :state_province_subdivision,
      "administrative_area_level_1" => [:state_province, :state_province_short],
      "country"                     => [:country, :country_short],
      "postal_code"                 => :postal_code,
      "postal_code_suffix"          => :postal_code_suffix,
      "post_box"                    => :post_box
    }

    components = result.data["address_components"] || []
    components.each do |component|
      type    = component["types"].first
      mapping = mappings[type]
      next unless mapping

      if mapping.is_a?(Array)
        self[mapping[0]] = component["long_name"]  if respond_to?("#{mapping[0]}=")
        self[mapping[1]] = component["short_name"] if respond_to?("#{mapping[1]}=")
      else
        self[mapping] = component["long_name"] if respond_to?("#{mapping}=")
      end
    end
  end

  # ===========================================================
  # 4. Prepare a partial address string for geocoding input
  # ===========================================================
  def build_input_address_for_geocoding
    parts = []
    parts << street_number if respond_to?(:street_number) && street_number.present?
    parts << street_name   if respond_to?(:street_name)   && street_name.present?
    parts << city          if respond_to?(:city)          && city.present?

    state =
      if respond_to?(:state_province_short)
        state_province_short
      elsif respond_to?(:state_province)
        state_province
      end
    parts << state if state.present?

    country =
      if respond_to?(:country_short)
        country_short
      elsif respond_to?(:country)
        country
      end
    parts << country if country.present?

    parts << postal_code if respond_to?(:postal_code) && postal_code.present?

    parts.compact.join(", ")
  end

  # ===========================================================
  # 5. Construct the printable full address from populated fields
  # ===========================================================
  def build_full_address
    formatted_postal =
      if respond_to?(:postal_code)
        suffix = respond_to?(:postal_code_suffix) ? postal_code_suffix.presence : nil
        [postal_code, suffix].compact.join("-")
      end

    components = []
    components << street_number          if respond_to?(:street_number)          && street_number.present?
    components << street_name            if respond_to?(:street_name)            && street_name.present?
    components << apartment_suite_number if respond_to?(:apartment_suite_number) && apartment_suite_number.present?
    components << city                   if respond_to?(:city)                   && city.present?
    components << state_province_short   if respond_to?(:state_province_short)   && state_province_short.present?
    components << country_short          if respond_to?(:country_short)          && country_short.present?
    components << formatted_postal       if formatted_postal.present?

    self.address = components.compact.join(", ") unless components.empty?
  end

  # ===========================================================
  # 6. Centralized logging (no validation blocking)
  # ===========================================================
  def log_geocode_warning(message)
    Rails.logger.warn(
      "[GeocodableWithFallback] #{self.class.name}(id=#{id || 'new'}): #{message}"
    )
  end
end
