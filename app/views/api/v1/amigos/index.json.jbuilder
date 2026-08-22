# app/views/api/v1/amigos/index.json.jbuilder

json.array! @amigos do |amigo|
  json.partial! 'api/v1/amigos/amigo', amigo: amigo
end