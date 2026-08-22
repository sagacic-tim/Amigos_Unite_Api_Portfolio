# app/views/api/v1/amigo_details/create.json.jbuilder
if @amigo_detail.persisted?
    json.amigo_detail do
      json.partial! 'api/v1/amigo_details/amigo_detail', amigo_detail: @amigo_detail
    end
else
json.errors @amigo_detail.errors.full_messages
end  