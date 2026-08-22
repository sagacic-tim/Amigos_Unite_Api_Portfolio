# app/views/api/v1/amigo_locations/index.json.jbuilder
json.array! @amigo_locations do |location|
  json.partial! 'api/v1/amigo_locations/location', location: location
end