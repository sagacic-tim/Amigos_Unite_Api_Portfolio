# app/views/api/v1/event_location_connectors/show.json.jbuilder
json.id @event_location_connector.id
json.event_id @event_location_connector.event_id
json.event_name @event_location_connector.event.event_name  # Assuming event has a name attribute
json.location_id @event_location_connector.event_location_id
json.location_details do
  json.business_name @event_location_connector.event_location.business_name
  json.address @event_location_connector.event_location.address
  json.latitude @event_location_connector.event_location.latitude
  json.longitude @event_location_connector.event_location.longitude
end