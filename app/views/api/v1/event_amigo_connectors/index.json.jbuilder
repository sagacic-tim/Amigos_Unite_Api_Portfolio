# app/views/api/v1/event_amigo_connectors/index.json.jbuilder
json.array! @event_amigo_connectors do |event_amigo_connector|
  json.partial! 'api/v1/event_amigo_connectors/event_amigo_connector', event_amigo_connector: event_amigo_connector
end