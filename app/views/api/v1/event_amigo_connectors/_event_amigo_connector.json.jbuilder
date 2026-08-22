# app/views/api/v1/event_amigo_connectors/_event_amigo_connector.json.jbuilder

json.extract! event_amigo_connector, :id, :event_id, :amigo_id, :role
json.amigo do
  json.partial! 'api/v1/amigos/amigo', amigo: event_amigo_connector.amigo
end
json.created_at event_amigo_connector.created_at
json.updated_at event_amigo_connector.updated_at