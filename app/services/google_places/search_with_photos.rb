# app/services/google_places/search_with_photos.rb
module GooglePlaces
  class SearchWithPhotos
    MAX_PLACES = 5

    def self.call(query)
      new(query).call
    end

    def initialize(query)
      @query = query.to_s.strip
    end

    def call
      return [] if @query.blank?

      client = GooglePlaces::Client.new
      client.search_places(@query, max_results: MAX_PLACES)
    end
  end
end
