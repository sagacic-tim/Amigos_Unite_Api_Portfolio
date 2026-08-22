
# app/serializers/amigo_location_serializer.rb
class AmigoLocationSerializer < ActiveModel::Serializer
  attributes :id, :amigo_id, :address, :floor, :street_number, :street_name,
             :room_no, :apartment_suite_number, :city_sublocality, :city,
             :state_province_subdivision, :state_province, :state_province_short,
             :country, :country_short, :postal_code, :postal_code_suffix,
             :post_box, :latitude, :longitude, :time_zone, :created_at, :updated_at
end
