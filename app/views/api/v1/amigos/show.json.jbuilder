# app/views/api/v1/amigos/show.json.jbuilder

# Render the amigo using the partial
json.amigo do
    json.partial! 'api/v1/amigos/amigo', amigo: @amigo
end
  