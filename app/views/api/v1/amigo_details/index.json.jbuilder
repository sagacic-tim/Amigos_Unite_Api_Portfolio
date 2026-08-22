# app/views/api/v1/amigo_details/index.json.jbuilder
json.array! @amigo_details do |amigo_detail|
    json.partial! 'api/v1/amigo_details/amigo_detail', amigo_detail: amigo_detail
  end  