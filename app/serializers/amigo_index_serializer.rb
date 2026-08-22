# app/serializers/amigo_index_serializer.rb
class AmigoIndexSerializer < ActiveModel::Serializer
  attributes :id, :first_name, :last_initial, :avatar_url

  def last_initial
    object.last_name&.first&.upcase
  end

  def avatar_url
    object.avatar_url_with_buster
  end
end
