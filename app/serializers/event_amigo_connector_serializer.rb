
# app/serializers/event_amigo_connector_serializer.rb
class EventAmigoConnectorSerializer < ActiveModel::Serializer
  attributes :id,
             :event_id,
             :amigo_id,
             :role,
             :status,
             :created_at,
             :updated_at

  # Use the same AmigoSerializer as elsewhere
  belongs_to :amigo, serializer: AmigoSerializer
end
