# app/views/api/v1/event_location_connectors/index.json.jbuilder
json.array! @event_location_connectors do |connector|
    json.id connector.id
    json.event_id connector.event_id
    json.location_id connector.event_location_id
    json.location_details do
        json.business_name connector.event_location.business_name
        json.address connector.event_location.address
        json.latitude connector.event_location.latitude
        json.longitude connector.event_location.longitude
    end
end