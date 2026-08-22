# app/services/events/upsert_primary_location.rb
require "open-uri"
require "securerandom"

module Events
  class UpsertPrimaryLocation
    # Public: Create or update the primary location for a given event.
    #
    # Parameters
    # ----------
    # event      - The Event instance whose primary location we are managing.
    # raw_attrs  - A hash of location attributes, e.g.:
    #              {
    #                business_name: "Dancing Mule Coffee Company",
    #                location_type: "Cafe",
    #                street_number: "1945",
    #                street_name:   "South Glenstone Avenue",
    #                city:          "Springfield",
    #                state_province:"Missouri",
    #                country:       "United States",
    #                postal_code:   "65804",
    #                owner_name:    "...",
    #                has_food:      true,
    #                has_drink:     true,
    #                has_internet:  true,
    #                has_big_screen:false,
    #                place_id:      "...",
    #                image_url:     "...",        # transient
    #                photo_reference:"..."        # transient
    #              }
    #
    # Returns the EventLocation instance if created/updated, or nil if the
    # payload was considered empty / not meaningful.
    def call(event:, raw_attrs:)
      attrs = (raw_attrs || {}).to_h.deep_symbolize_keys

      # Optional debug:
      Rails.logger.debug("[UpsertPrimaryLocation] attrs: #{attrs.inspect}")

      # Skip if there's no meaningful location data
      return unless location_present?(attrs)

      image_url       = attrs.delete(:image_url)
      photo_reference = attrs.delete(:photo_reference)

      # Reuse existing primary location if present, otherwise build new.
      event_location = event.primary_event_location || EventLocation.new

      event_location.assign_attributes(
        business_name:              attrs[:business_name],
        business_phone:             attrs[:business_phone],
        location_type:              attrs[:location_type],
        street_number:              attrs[:street_number],
        street_name:                attrs[:street_name],
        city:                       attrs[:city],
        state_province:             attrs[:state_province],
        country:                    attrs[:country],
        postal_code:                attrs[:postal_code],
        owner_name:                 attrs[:owner_name],
        capacity:                   attrs[:capacity],
        capacity_seated:            attrs[:capacity_seated],
        availability_notes:         attrs[:availability_notes],

        # ─── Boolean flags: NEVER write nil (DB is null: false, default: false) ───
        has_food:       normalize_boolean(attrs, :has_food),
        has_drink:      normalize_boolean(attrs, :has_drink),
        has_internet:   normalize_boolean(attrs, :has_internet),
        has_big_screen: normalize_boolean(attrs, :has_big_screen),

        place_id:                   attrs[:place_id],
        location_image_attribution: attrs[:location_image_attribution],

        search_criteria:    normalize_string_array(attrs[:search_criteria], EventLocation::MAX_SEARCH_CRITERIA),
        search_venue_types: normalize_string_array(attrs[:search_venue_types], EventLocation::MAX_SEARCH_VENUE_TYPES)
      )

      # Geocoding / time zone handled by GeocodableWithFallback callbacks.
      event_location.save!

      # Ensure a primary connector exists for this event/location.
      EventLocationConnector.find_or_create_by!(
        event:          event,
        event_location: event_location
      ) do |connector|
        connector.is_primary = true
        connector.status     = :confirmed
      end

      attach_location_image_from_payload(event_location, image_url, photo_reference)

      event_location
    end

    private

    # Basic check that the location isn't just empty noise.
    #
    # We treat a payload as "present" if *any* of these are present:
    # - business_name
    # - street_name
    # - city
    # - place_id
    def location_present?(attrs)
      name_present   = attrs[:business_name].present?
      street_present = attrs[:street_name].present?
      city_present   = attrs[:city].present?
      place_present  = attrs[:place_id].present?

      name_present || street_present || city_present || place_present
    end

    # Treat missing keys or nil as false; cast truthy/falsey values to a real boolean.
    #
    # This keeps DB booleans strictly 2-state (true/false), while allowing the UI to
    # treat these flags as “optional”. Absence → false.
    def normalize_boolean(attrs, key)
      return false unless attrs.key?(key)
      ActiveModel::Type::Boolean.new.cast(attrs[key])
    end

    # Absence → [] (mirrors normalize_boolean's "absence → false" convention).
    # Strips blank entries and caps to the given limit.
    def normalize_string_array(value, cap)
      Array(value).map(&:to_s).map(&:strip).reject(&:blank?).first(cap)
    end

    def attach_location_image_from_payload(event_location, image_url, photo_reference)
      remote_url = image_url.presence || photo_reference_to_url(photo_reference)
      return if remote_url.blank?

      file = URI.open(remote_url)

      content_type = file.respond_to?(:content_type) ? file.content_type : "image/jpeg"
      extension    = Rack::Mime::MIME_TYPES.invert[content_type] || ".jpg"
      filename     = "event-location-#{SecureRandom.hex(8)}#{extension}"

      event_location.location_image.attach(
        io:          file,
        filename:    filename,
        content_type: content_type
      )
    rescue => e
      Rails.logger.warn(
        "[Events::UpsertPrimaryLocation] Failed to attach location image: #{e.class}: #{e.message}"
      )
    end

    def photo_reference_to_url(photo_reference)
      return if photo_reference.blank?

      api_key = ENV["GOOGLE_MAPS_API_KEY"]
      return if api_key.blank?

      params = {
        maxwidth:       1600,
        photoreference: photo_reference,
        key:            api_key
      }

      "https://maps.googleapis.com/maps/api/place/photo?#{params.to_query}"
    end
  end
end
