# # app/views/api/v1/event_location_connectors/update.json.jbuilder
# json.partial! 'api/v1/event_location_connectors/event_location_connector', connector: @event_location_connector

json.event_location_connector_id @event_location_connector.id
json.event_id @event_location_connector.event_id
json.event_name @event_location_connector.event.event_name
json.event_date @event_location_connector.event.event_date.strftime('%Y-%m-%d')
json.event_time @event_location_connector.event.event_time.strftime('%H:%M:%S')

json.event_location_id @event_location_connector.event_location_id
json.business_name @event_location_connector.event_location.business_name
json.business_address do
  json.street @event_location_connector.event_location.street_name
  json.city @event_location_connector.event_location.city
  json.state @event_location_connector.event_location.state_province
  json.postal_code @event_location_connector.event_location.postal_code
  json.country @event_location_connector.event_location.country
end
json.latitude @event_location_connector.event_location.latitude
json.longitude @event_location_connector.event_location.longitude