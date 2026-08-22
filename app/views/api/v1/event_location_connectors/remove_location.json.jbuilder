# app/views/api/v1/event_location_connectors/remove_location.json.jbuilder

if defined?(@error)
    json.error @error
else
    json.message 'Location successfully disconnected from event'
end