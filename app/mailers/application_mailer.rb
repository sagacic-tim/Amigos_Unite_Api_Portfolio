# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "no-replies@amigosunite.org")
  layout "mailer"
end
