
# app/serializers/event_location_serializer.rb
class EventLocationSerializer < ActiveModel::Serializer
  attributes :id,
             :location_type,
             :business_name,
             :business_phone,
             :address,
             :floor,
             :street_number,
             :street_name,
             :room_no,
             :apartment_suite_number,
             :city_sublocality,
             :city,
             :state_province_subdivision,
             :state_province,
             :state_province_short,
             :country,
             :country_short,
             :postal_code,
             :postal_code_suffix,
             :post_box,
             :latitude,
             :longitude,
             :time_zone,
             :owner_name,
             :capacity,
             :capacity_seated,
             :availability_notes,
             :has_food,
             :has_drink,
             :has_internet,
             :has_big_screen,
             :place_id,
             :search_criteria,
             :search_venue_types,
             :location_image_url,
             :location_image_attribution,
             :created_at,
             :updated_at

  # If you want to ensure we always expose the URL correctly:
  def location_image_url
    object.location_image_url
  end
end
