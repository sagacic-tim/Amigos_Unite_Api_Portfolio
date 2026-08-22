# app/services/google_places/fetch_photos_for_place.rb
module GooglePlaces
  class FetchPhotosForPlace
    def self.call(place_id)
      new(place_id).call
    end

    def initialize(place_id)
      @place_id = place_id.to_s
    end

    def call
      return [] if @place_id.blank?

      client = GooglePlaces::Client.new
      # This returns an array of up to 5 photo hashes
      client.photos_for_place(@place_id)
    end
  end
end
