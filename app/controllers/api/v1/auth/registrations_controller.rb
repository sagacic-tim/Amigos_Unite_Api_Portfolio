# app/controllers/api/v1/auth/registrations_controller.rb
module Api
  module V1
    module Auth
      class RegistrationsController < ApplicationController
        # Signup is public: no existing JWT required
        skip_before_action :authenticate_amigo!, only: :create

        # POST /api/v1/signup
        def create
          amigo = Amigo.new(sign_up_params)

          if amigo.save
            expires_at = 12.hours.from_now

            # Issue JWT (match SessionsController’s behavior for consistency)
            token = JsonWebToken.encode({ sub: amigo.id }, expires_at)

            cookies.signed[:jwt] = {
              value:     token,
              httponly:  true,
              secure:    true,          # required with SameSite=None in cross-origin setups
              same_site: :none,
              path:      '/',
              expires:   expires_at
            }

            # Expose CSRF token to SPA (same pattern as SessionsController)
            cookies['CSRF-TOKEN'] = {
              value:     form_authenticity_token,
              same_site: :none,
              secure:    true,
              http_only: false,
              path:      '/'
            }

            amigo_payload = {
              id:         amigo.id,
              user_name:  amigo.user_name,
              email:      amigo.email,
              first_name: amigo.first_name,
              last_name:  amigo.last_name,
              phone_1:    amigo.phone_1
            }

            render json: {
              status: { code: 200, message: 'Signed up successfully. Welcome, Amigo!' },
              data:   {
                amigo:          amigo_payload,
                jwt_expires_at: expires_at.utc.iso8601
              }
            }, status: :ok
          else
            render json: {
              status: {
                code:    422,
                message: 'Signup failed.',
                errors:  amigo.errors.full_messages
              }
            }, status: :unprocessable_content
          end
        end

        private

        # Combine the richer param list from the old RegistrationsController
        def sign_up_params
          params.require(:amigo).permit(
            :first_name,
            :last_name,
            :user_name,
            :email,
            :phone_1,
            :password,
            :password_confirmation
          )
        end

        # Keep this for when you wire up account update later
        def account_update_params
          params.require(:amigo).permit(
            :first_name,
            :last_name,
            :user_name,
            :email,
            :secondary_email,
            :phone_1,
            :phone_2,
            :password,
            :password_confirmation,
            :current_password,
            :avatar
          )
        end
      end
    end
  end
end
