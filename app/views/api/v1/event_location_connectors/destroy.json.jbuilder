# app/views/api/v1/event_location_connectors/destroy.json.jbuilder
if @error_message
    json.error @error_message
  else
    json.message "Event Location Connector successfully deleted"
  end  