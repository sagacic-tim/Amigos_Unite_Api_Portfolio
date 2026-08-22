# app/views/api/v1/event_locations/index.json.jbuilder

json.array! @event_locations do |location|
  json.partial! 'api/v1/event_locations/event_location', event_location: location
end