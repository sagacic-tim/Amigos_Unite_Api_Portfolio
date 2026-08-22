
# app/serializers/amigo_detail_serializer.rb
class AmigoDetailSerializer < ActiveModel::Serializer
  attributes :id, :amigo_id, :date_of_birth,
             :member_in_good_standing, :available_to_host,
             :willing_to_help, :willing_to_donate,
             :personal_bio, :created_at, :updated_at
end
