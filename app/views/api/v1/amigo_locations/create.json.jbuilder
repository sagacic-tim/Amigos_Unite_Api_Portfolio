# app/views/api/v1/amigo_locations/create.json.jbuilder
if @amigo_location.persisted?
  json.partial! 'api/v1/amigo_locations/location', location: @amigo_location
else
  json.errors @amigo_location.errors.full_messages
end