# app/controllers/api/v1/places_controller.rb
module Api
  module V1
    class PlacesController < ApplicationController
      before_action :authenticate_amigo!

      # GET /api/v1/places/search?q=...&type=cafe
      def search
        query = params[:q].to_s.strip
        type  = params[:type].presence

        return render(json: [], status: :ok) if query.blank?

        client  = GooglePlaces::Client.new
        results = client.search_places(query, max_results: 5, type: type)

        render json: results, status: :ok
      rescue GooglePlaces::Error => e
        Rails.logger.error("[PlacesController#search] #{e.class}: #{e.message}")
        Rails.logger.error("[PlacesController#search] details=#{e.details.inspect}") if e.details.present?
        render json: { error: "Places lookup failed" }, status: (e.status || :bad_gateway)
      rescue StandardError => e
        Rails.logger.error("[PlacesController#search] #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
        render json: { error: "Places lookup failed" }, status: :service_unavailable
      end

      # GET /api/v1/places/:id/photos
      def photos
        place_id = params[:id].to_s.strip
        return render(json: [], status: :ok) if place_id.blank?

        photos = GooglePlaces::FetchPhotosForPlace.call(place_id)
        render json: photos, status: :ok
      rescue GooglePlaces::Error => e
        Rails.logger.error("[PlacesController#photos] #{e.class}: #{e.message}")
        Rails.logger.error("[PlacesController#photos] details=#{e.details.inspect}") if e.details.present?
        render json: { error: "Photo lookup failed" }, status: (e.status || :bad_gateway)
      rescue StandardError => e
        Rails.logger.error("[PlacesController#photos] #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
        render json: { error: "Photo lookup failed" }, status: :service_unavailable
      end

      # GET /api/v1/places/:id/address
      #
      # Returns structured address components for a place_id so the frontend
      # can pre-fill Step 6 fields that the Nearby Search "vicinity" string
      # omits (postal_code, postal_code_suffix, state_province_short, etc.).
      def address
        place_id = params[:id].to_s.strip
        return render(json: {}, status: :ok) if place_id.blank?

        components = GooglePlaces::Client.new.address_for_place(place_id)
        render json: components, status: :ok
      rescue GooglePlaces::Error => e
        Rails.logger.error("[PlacesController#address] #{e.class}: #{e.message}")
        Rails.logger.error("[PlacesController#address] details=#{e.details.inspect}") if e.details.present?
        render json: { error: "Address lookup failed" }, status: (e.status || :bad_gateway)
      rescue StandardError => e
        Rails.logger.error("[PlacesController#address] #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
        render json: { error: "Address lookup failed" }, status: :service_unavailable
      end
    end
  end
end
