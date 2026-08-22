# app/mailers/moderation_mailer.rb
class ModerationMailer < ApplicationMailer
  # Notifies an amigo that their uploaded image was removed by automated moderation.
  #
  # amigo           — Amigo record
  # attachment_name — string, e.g. 'avatar', 'location_image'
  def image_removed(amigo, attachment_name)
    @amigo           = amigo
    @attachment_name = humanize_attachment(attachment_name)

    mail(
      to:      amigo.email,
      subject: 'Your uploaded image was removed'
    )
  end

  private

  def humanize_attachment(name)
    case name.to_s
    when 'avatar'         then 'profile photo'
    when 'location_image' then 'location image'
    else name.to_s.humanize.downcase
    end
  end
end
