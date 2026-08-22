# app/controllers/api/v1/auth/passwords_controller.rb
module Api
  module V1
    module Auth
      class PasswordsController < Devise::PasswordsController
        respond_to :json

        # Public endpoint
        skip_before_action :authenticate_amigo!, raise: false

        # Keep your custom CSRF verification ON (your spec supplies CSRF header + cookie).
        # Do NOT call Devise flash helpers (successfully_sent?, set_flash_message, etc.)

        # POST /api/v1/amigos/password
        def create
          # Devise enqueues the email via this call when a user exists.
          self.resource = resource_class.send_reset_password_instructions(resource_params)

          # In API mode: determine success without flash.
          #
          # Devise behavior:
          # - If email exists: resource.errors usually empty and email job enqueued
          # - If email does not exist: by default it may STILL be treated as success
          #   (to avoid user enumeration) depending on Devise settings.
          #
          # We will treat "no validation errors" as success.
          if resource.errors.empty?
            render json: {
              status: { code: 200, message: "Reset password instructions sent." }
            }, status: :ok
          else
            render json: {
              status: {
                code: 422,
                message: "Unable to send reset instructions.",
                errors: resource.errors.full_messages
              }
            }, status: :unprocessable_entity
          end
        end

        protected

        def resource_name
          :amigo
        end

        def resource_params
          params.require(:amigo).permit(:email)
        end
      end
    end
  end
end
