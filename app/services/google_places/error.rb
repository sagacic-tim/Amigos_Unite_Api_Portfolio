# app/services/google_places/error.rb
module GooglePlaces
  class Error < StandardError
    attr_reader :http_code, :google_status

    def initialize(message, http_code: nil, google_status: nil)
      super(message)
      @http_code    = http_code
      @google_status = google_status
    end
  end
end
