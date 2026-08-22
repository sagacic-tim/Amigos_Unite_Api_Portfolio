# app/mailers/contact_mailer.rb

class ContactMailer < ApplicationMailer
  def contact_message(first_name:, last_name:, email:, message:)
    @first_name = first_name
    @last_name  = last_name
    @email      = email
    @body_text  = message

    mail(
      to:       ENV.fetch("CONTACT_INBOX", "no-replies@amigosunite.org"),
      from:     ENV.fetch("MAIL_FROM", "no-replies@amigosunite.org"),
      reply_to: email,
      subject:  "New contact from #{@first_name} #{@last_name}"
    )
  end
end

