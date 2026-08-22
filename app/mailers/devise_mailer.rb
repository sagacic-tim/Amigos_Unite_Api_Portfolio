# app/mailers/devise_mailer.rb
class DeviseMailer < Devise::Mailer
  # Inherit your ApplicationMailer defaults (layout, host, etc.)
  default from: ENV.fetch("MAIL_FROM", "no-replies@amigosunite.org")

  # Do NOT call deliver_later here.
  # Devise / ActionMailer will deliver (and in test it will populate deliveries).
end
