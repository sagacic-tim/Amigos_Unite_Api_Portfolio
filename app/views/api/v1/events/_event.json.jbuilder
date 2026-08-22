# app/views/api/v1/events/_event.json.jbuilder

json.extract! event,
  :id,
  :event_name,
  :event_type,
  :event_speakers_performers,
  :event_date,
  :event_time

json.lead_coordinator do
  json.partial! 'api/v1/amigos/amigo', amigo: event.lead_coordinator
end

json.created_at event.created_at
json.updated_at event.updated_at