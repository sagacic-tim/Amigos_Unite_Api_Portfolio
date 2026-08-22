# app/views/api/v1/amigo_details/update.json.jbuilder
if @amigo_detail.errors.any?
    json.errors @amigo_detail.errors.full_messages
  else
    json.amigo_detail do
      json.partial! 'api/v1/amigo_details/amigo_detail', amigo_detail: @amigo_detail
    end
  end  