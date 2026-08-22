json.extract! event_location, 
  :id,
  :business_name,
  :business_phone,
  :floor,
  :room_no,
  :apartment_suite_number,
  :street_number,
  :street_name,
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
  :latitude ,
  :longitude,
  :time_zone,
  :created_at,
  :updated_at

  # if event_location.location_image.attached?
  #   resized_image = event_location.location_image.variant(resize: "640x480").processed
  #   json.location_image_url rails_representation_url(resized_image, only_path: true)
  # end

json.created_at event_location.created_at
json.updated_at event_location.updated_at
