class CreateEventLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :event_locations do |t|
      t.string :business_name, limit: 64, comment: "Name of the venue or business hosting the event"
      t.string :business_phone, limit: 15, comment: "Primary phone number of the business or venue"
      t.string :address, limit: 256, comment: "Full mailing address (may include suite, floor, etc.)"
      t.string :floor, limit: 10, comment: "Floor number if the venue is in a multi-story building"
      t.string :street_number, limit: 32, comment: "Street number of the location"
      t.string :street_name, limit: 96, comment: "Street name of the location"
      t.string :room_no, limit: 32, comment: "Specific room or unit number"
      t.string :apartment_suite_number, limit: 32, comment: "Suite or apartment number if applicable"
      t.string :city_sublocality, limit: 96, comment: "Sub-locality or neighborhood (e.g., district or borough)"
      t.string :city, limit: 64, comment: "City where the event location is situated"
      t.string :state_province_subdivision, limit: 96, comment: "County, prefecture, or similar subdivision"
      t.string :state_province, limit: 32, comment: "State or province name"
      t.string :state_province_short, limit: 8, comment: "Abbreviated state or province code (e.g., CA)"
      t.string :country, limit: 32, comment: "Full country name"
      t.string :country_short, limit: 3, comment: "ISO 3166-1 alpha-2 or alpha-3 country code"
      t.string :postal_code, limit: 12, comment: "ZIP or postal code"
      t.string :postal_code_suffix, limit: 6, comment: "Additional postal code information (e.g., ZIP+4)"
      t.string :post_box, limit: 12, comment: "Post office box number, if applicable"
      t.float :latitude, comment: "Latitude coordinate for geolocation"
      t.float :longitude, comment: "Longitude coordinate for geolocation"
      t.string :time_zone, limit: 48, comment: "Time zone of the event location (e.g., 'Pacific Time (US & Canada)')"
      t.integer :status, default: 0, null: false, comment: "Status of the location (e.g., active/inactive), stored as enum"

      t.timestamps
    end
  end
end
