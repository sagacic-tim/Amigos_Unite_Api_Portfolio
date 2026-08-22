# app/views/api/v1/amigos/update.json.jbuilder

if @amigo.errors.any?
  json.errors @amigo.errors.full_messages
else
  json.partial! 'api/v1/amigos/amigo', amigo: @amigo
end