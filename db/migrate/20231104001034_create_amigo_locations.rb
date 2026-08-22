class CreateAmigoLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :amigo_locations do |t|
      t.references :amigo, null: false, foreign_key: true, comment: "Foreign key reference to the Amigo record"
      t.string  :address, limit: 256, comment: "Full formatted address"
      t.string  :floor, limit: 10, comment: "Floor number (if applicable)"
      t.string  :street_number, limit: 32, comment: "Street number of the address"
      t.string  :street_name, limit: 96, comment: "Street name of the address"
      t.string  :room_no, limit: 32, comment: "Room number (e.g., hotel or dormitory)"
      t.string  :apartment_suite_number, limit: 32, comment: "Apartment or suite number"
      t.string  :city_sublocality, limit: 96, comment: "Neighborhood, district, or sublocality within the city"
      t.string  :city, limit: 64, comment: "City of the address"
      t.string  :state_province_subdivision, limit: 96, comment: "County or sub-region within the state/province"
      t.string  :state_province, limit: 32, comment: "Full state or province name"
      t.string  :state_province_short, limit: 8, comment: "Abbreviated state or province code"
      t.string  :country, limit: 32, comment: "Full country name"
      t.string  :country_short, limit: 3, comment: "ISO country code (e.g., US)"
      t.string  :postal_code, limit: 12, comment: "Postal or ZIP code"
      t.string  :postal_code_suffix, limit: 6, comment: "Extra postal code details (e.g., ZIP+4)"
      t.string  :post_box, limit: 12, comment: "PO Box number if applicable"
      t.float   :latitude, comment: "Latitude coordinate for geolocation"
      t.float   :longitude, comment: "Longitude coordinate for geolocation"
      t.string  :time_zone, limit: 48, comment: "Time zone of the location"

      t.timestamps
    end
  end
end
