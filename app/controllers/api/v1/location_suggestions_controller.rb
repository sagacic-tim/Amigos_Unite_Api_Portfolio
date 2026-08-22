# app/controllers/api/v1/location_suggestions_controller.rb
module Api
  module V1
    class LocationSuggestionsController < ApplicationController
      before_action :authenticate_amigo!

      # POST /api/v1/location_suggestions
      #
      # Body params:
      #   city             String  (required)
      #   state_province   String
      #   country          String
      #   venue_name       String  (optional — if present, searches only for this
      #                            named venue and skips the Claude filter step)
      #   criteria         Array<String>   (up to 5 free-text criteria)
      #   venue_types      Array<String>   (up to 3 venue category keys)
      #   lat              Float  (optional — if omitted, geocoded from city)
      #   lng              Float  (optional)
      #   event_start_time String  "HH:MM" (optional)
      #
      # Returns an array of up to 20 place objects.
      def create
        city              = params[:city].to_s.strip
        state_province    = params[:state_province].to_s.strip
        country           = params[:country].to_s.strip
        venue_name        = params[:venue_name].to_s.strip
        criteria          = Array(params[:criteria]).map(&:to_s).reject(&:blank?)
        venue_types       = Array(params[:venue_types]).map(&:to_s).reject(&:blank?).first(3)
        lat               = params[:lat].presence&.to_f
        lng               = params[:lng].presence&.to_f
        event_start_time  = params[:event_start_time].to_s.strip  # "HH:MM"

        if city.blank?
          return render json: { error: "city is required" }, status: :unprocessable_entity
        end

        results = GooglePlaces::AiLocationSuggestions.call(
          city:             city,
          state_province:   state_province,
          country:          country,
          venue_name:       venue_name,
          criteria:         criteria,
          venue_types:      venue_types,
          lat:              lat,
          lng:              lng,
          event_start_time: event_start_time
        )

        render json: results, status: :ok

      rescue GooglePlaces::Error => e
        Rails.logger.error("[LocationSuggestionsController] #{e.class}: #{e.message}")
        render json: { error: e.message }, status: (e.http_code || 502)
      rescue StandardError => e
        Rails.logger.error("[LocationSuggestionsController] #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        render json: { error: "Location suggestions unavailable" }, status: :service_unavailable
      end
    end
  end
end
