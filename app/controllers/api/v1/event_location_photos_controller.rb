
# app/controllers/api/v1/event_location_photos_controller.rb
module Api
  module V1
    class EventLocationPhotosController < ApplicationController
      before_action :authenticate_amigo!
      before_action :set_location

      def create
        photo_name = params.require(:photo_name)
        place_id   = params.require(:place_id)

        client = GooglePlaces::Client.new
        bytes  = client.fetch_photo_bytes(photo_name)

        @location.place_id = place_id
        @location.location_image.attach(
          io: StringIO.new(bytes),
          filename: "event_location_#{@location.id}.jpg",
          content_type: "image/jpeg" # or detect type
        )

        # Optionally store any attribution text passed up from the frontend
        @location.location_image_attribution = params[:attribution]
        @location.save!

        # Moderate in background — image is purged automatically if it fails SafeSearch
        ModerateImageJob.perform_later('EventLocation', @location.id, 'location_image')

        render json: EventLocationSerializer.new(@location).as_json, status: :created
      end

      private

      def set_location
        @location = EventLocation.find(params[:event_location_id])
      end
    end
  end
end
