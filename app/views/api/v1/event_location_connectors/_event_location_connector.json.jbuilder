# app/views/api/v1/event_location_connectors/_event_location_connector.json.jbuilder

json.id connector.id
json.event do
  json.partial! 'api/v1/events/event', event: connector.event
end
json.event_location do
  json.partial! 'api/v1/event_locations/event_location', event_location: connector.event_location
end