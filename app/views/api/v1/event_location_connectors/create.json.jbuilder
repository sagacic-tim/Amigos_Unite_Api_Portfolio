# app/views/api/v1/event_location_connectors/create.json.jbuilder
if defined?(@errors)
  json.errors @errors
elsif defined?(@message)
  json.message @message
  if @event_location_connector.persisted?
    json.event_location_connector do
      json.extract! @event_location_connector, :id, :event_id, :event_location_id
      json.location_details do
        json.business_name @event_location_connector.event_location.business_name
        json.address @event_location_connector.event_location.address
        json.latitude @event_location_connector.event_location.latitude
        json.longitude @event_location_connector.event_location.longitude
      end
    end
  end
end