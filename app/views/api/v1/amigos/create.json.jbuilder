# app/views/api/v1/amigos/create.json.jbuilder

  json.partial! 'api/v1/amigos/amigo', amigo: @amigo
  json.authentication_token @amigo.authentication_token if @amigo.respond_to?(:authentication_token)