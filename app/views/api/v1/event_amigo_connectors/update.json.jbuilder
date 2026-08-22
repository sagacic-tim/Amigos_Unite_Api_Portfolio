# app/views/api/v1/event_amigo_connectors/update.json.jbuilder

if @event_amigo_connector.errors.any?
  json.errors @event_amigo_connector.errors.full_messages
else
  json.partial! 'api/v1/event_amigo_connectors/event_amigo_connector', event_amigo_connector: @event_amigo_connector
end