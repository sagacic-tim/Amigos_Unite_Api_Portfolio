# app/serializers/amigo_serializer.rb
class AmigoSerializer < ActiveModel::Serializer
  attributes  :id, :first_name, :last_name, :user_name, :email,
              :secondary_email, :phone_1, :phone_2, :avatar_url,
              :full_name, :formatted_created_at, :formatted_updated_at,
              :willing_to_help

  has_one  :amigo_detail,    serializer: AmigoDetailSerializer
  has_many :amigo_locations, serializer: AmigoLocationSerializer

  def formatted_created_at
    object.created_at&.strftime("%Y-%m-%d %H:%M:%S")
  end

  def formatted_updated_at
    object.updated_at&.strftime("%Y-%m-%d %H:%M:%S")
  end

  def full_name
    [object.first_name, object.last_name].compact.join(' ').strip
  end

  def phone_1
    present_and_format_phone(object.phone_1)
  end

  def phone_2
    present_and_format_phone(object.phone_2)
  end

  def avatar_url
    # Do NOT bypass the model logic; return exactly what the FE expects (relative path with buster, or a fallback)
    object.avatar_url_with_buster
  end

  def willing_to_help
    object.amigo_detail&.willing_to_help
  end

  private

  def present_and_format_phone(raw)
    return nil if raw.blank?
    Phonelib.parse(raw).international
  end
end
