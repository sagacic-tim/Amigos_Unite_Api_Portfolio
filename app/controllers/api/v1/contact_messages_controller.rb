# app/controllers/api/v1/contact_messages_controller.rb
class Api::V1::ContactMessagesController < ApplicationController
  # because I haveIf an auth filter set globally:
  skip_before_action :authenticate_amigo!, only: :create

  def create
    p = params.require(:contact_message).permit(:first_name, :last_name, :email, :message)

    ContactMailer.contact_message(
      first_name: p[:first_name],
      last_name:  p[:last_name],
      email:      p[:email],
      message:    p[:message]
    ).deliver_later

    render json: { ok: true }
  end
end
