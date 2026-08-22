# app/views/api/v1/amigo_locations/update.json.jbuilder
if @amigo_location.errors.any?
  json.errors @amigo_location.errors.full_messages
else
  json.partial! 'api/v1/amigo_locations/location', location: @amigo_location
end