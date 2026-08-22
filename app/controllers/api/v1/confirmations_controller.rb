
# app/controllers/api/v1/confirmations_controller.rb
class Api::V1::ConfirmationsController < ApplicationController
  skip_before_action :authenticate_amigo! rescue nil
  protect_from_forgery with: :null_session

  # GET /api/v1/confirmations?token=abcdef
  def show
    token = params[:token].to_s
    amigo = Amigo.confirm_by_token(token)
    if amigo.errors.empty?
      render json: { status: "ok" }
    else
      render json: { status: "error", errors: amigo.errors.full_messages }, status: :unprocessable_content
    end
  end

  # POST /api/v1/confirmations (resend)
  def create
    email = params[:email].to_s
    amigo = Amigo.find_by(email: email)
    if amigo.blank?
      head :no_content and return
    end

    if amigo.confirmed?
      render json: { status: "already_confirmed" }
    else
      amigo.send_confirmation_instructions
      render json: { status: "sent" }
    end
  end
end
