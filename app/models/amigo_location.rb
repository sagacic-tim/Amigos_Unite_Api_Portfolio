# app/models/amigo_location.rb
class AmigoLocation < ApplicationRecord
  include GeocodableWithFallback

  # ====================
  # Associations
  # ====================
  belongs_to :amigo

  # ====================
  # Validations
  # ====================
  validates :address, presence: true, length: { maximum: 256 }

  validates :floor, :room_no, :apartment_suite_number, :street_number,
            :street_name, :city_sublocality, :city,
            :state_province_subdivision, :state_province,
            :state_province_short, :country, :country_short,
            :postal_code, :postal_code_suffix, :post_box,
            length: { maximum: 96 }

  validates :floor, length: { maximum: 10 }
  validates :room_no, :apartment_suite_number, :street_number, length: { maximum: 32 }
  validates :state_province, length: { maximum: 32 }
  validates :state_province_short, length: { maximum: 8 }
  validates :country_short, length: { maximum: 3 }
  validates :postal_code, length: { maximum: 12 }
  validates :postal_code_suffix, length: { maximum: 6 }
  validates :post_box, length: { maximum: 12 }
  validates :time_zone, length: { maximum: 48 }

  validates :latitude,  numericality: { greater_than_or_equal_to: -90,  less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
end
