# app/views/api/v1/amigo_locations/show.json.jbuilder
if @amigo_location
    json.partial! 'api/v1/amigo_locations/location', location: @amigo_location
else
json.error 'Location not found'
end