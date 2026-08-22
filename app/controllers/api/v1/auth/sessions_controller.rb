# app/controllers/api/v1/auth/sessions_controller.rb
module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        # Ensure Devise uses the :amigo mapping for these routes
        prepend_before_action -> { request.env['devise.mapping'] = Devise.mappings[:amigo] }

        include ActionController::MimeResponds
        include ActionController::Cookies
        include ActionController::RequestForgeryProtection

        respond_to :json

        # Devise filters we don't want for API
        skip_before_action :verify_signed_out_user, only: :destroy
        skip_before_action :authenticate_amigo!, raise: false

        # CSRF should NOT block API auth endpoints themselves
        skip_before_action :verify_authenticity_token,
          only: %i[create refresh destroy verify_token],
          raise: false

        # Force JSON format
        before_action :set_default_format

        ACCESS_TOKEN_TTL = 12.hours

        # Catch any uncaught exceptions in this controller and render JSON
        rescue_from StandardError do |e|
          Rails.logger.error(
            "Unhandled error in SessionsController##{action_name}: " \
            "#{e.class}: #{e.message}\n#{Array(e.backtrace).first(5).join("\n")}"
          )
          render json: { status: { code: 500, message: 'Internal Server Error' } },
                 status: :internal_server_error
        end

        # POST /api/v1/login
        def create
          amigo = authenticate_amigo(params[:amigo])
          return unless amigo

          # Sign a new JWT and set cookie
          expires_at = ACCESS_TOKEN_TTL.from_now
          token      = JsonWebToken.encode({ sub: amigo.id }, expires_at)

          log_token_presence('create-before')
          set_jwt_cookie(token, expires_at)
          log_token_presence('create-after')

          # Also (re)issue CSRF token cookie
          cookies['CSRF-TOKEN'] = {
            value:     form_authenticity_token,
            same_site: Rails.env.development? ? :none : :strict,
            secure:    true,
            http_only: false,
            path:      '/'
          }

          amigo_attrs = {
            id:         amigo.id,
            user_name:  amigo.user_name,
            email:      amigo.email,
            first_name: amigo.first_name,
            last_name:  amigo.last_name
          }

          render json: {
            status: { code: 200, message: 'Logged in successfully.' },
            data:   {
              amigo:          amigo_attrs,
              jwt_expires_at: expires_at.utc.iso8601
            }
          }, status: :ok
        end

        # DELETE /api/v1/logout

        def destroy
          log_token_presence('logout')
          token = cookies.signed[:jwt] || bearer_token

          if token.present?
            begin
              # permit logout even if token is expired
              payload = JsonWebToken.decode_allow_expired(token)
              JwtDenylist.revoke_jwt(payload, nil)

            rescue JsonWebToken::RevokedTokenError
              Rails.logger.info "Logout: token already revoked, continuing to clear cookies"

            rescue JWT::DecodeError => e
              Rails.logger.warn "Logout: token decode failed: #{e.message}"
              # still clear cookies and return 204
            end
          else
            Rails.logger.info "Logout called with no token; treating as already signed-out"
          end

          cookies.delete(:jwt,         path: '/', same_site: :none, secure: true)
          cookies.delete('CSRF-TOKEN', path: '/', same_site: :none, secure: true)

          head :no_content
        end

        # POST /api/v1/refresh_token

        def refresh
          log_token_presence('refresh')
          token = cookies.signed[:jwt] || bearer_token
          return render_error('Token missing', :unauthorized) unless token

          begin
            # allow expired tokens here (signature still required)
            payload = JsonWebToken.decode_allow_expired(token)
            amigo   = Amigo.find(payload[:sub])

            expires_at = ACCESS_TOKEN_TTL.from_now
            new_token  = JsonWebToken.encode({ sub: amigo.id }, expires_at)
            set_jwt_cookie(new_token, expires_at)

            # rotate CSRF token too
            cookies['CSRF-TOKEN'] = {
              value:     form_authenticity_token,
              same_site: Rails.env.development? ? :none : :strict,
              secure:    true,
              http_only: false,
              path:      '/'
            }

            render json: {
              status: { code: 200, message: 'Token refreshed successfully.' },
              data:   { jwt_expires_at: expires_at.utc.iso8601 }
            }, status: :ok

          rescue JsonWebToken::RevokedTokenError
            render_error('Token has been revoked', :unauthorized)

          rescue ActiveRecord::RecordNotFound
            render_error('Amigo not found', :unauthorized)

          rescue JWT::DecodeError => e
            Rails.logger.error "Refresh decode error: #{e.message}"
            render_error('Invalid token', :unauthorized)
          end
        end

        # GET /api/v1/verify_token

        def verify_token
          log_token_presence('verify')
          token = cookies.signed[:jwt] || bearer_token
          return render json: { valid: false, reason: 'Missing token' },
                        status: :unauthorized if token.blank?

          begin
            payload = JsonWebToken.decode(token)  # will raise on invalid/expired/revoked
            exp     = (payload[:exp] || payload['exp']).to_i
            return render json: { valid: false, reason: 'Missing exp' },
                          status: :unauthorized if exp.zero?

            exp_time = Time.at(exp).utc
            render json: { valid: true, expires_at: exp_time.iso8601 }, status: :ok

          rescue JsonWebToken::RevokedTokenError
            render json: { valid: false, reason: 'Token has been revoked' }, status: :unauthorized

          rescue JWT::ExpiredSignature
            render json: { valid: false, reason: 'Token expired' }, status: :unauthorized

          rescue JWT::DecodeError => e
            render json: { valid: false, reason: e.message }, status: :unauthorized
          end
        end

        private

        def log_token_presence(tag)
          Rails.logger.info(
            "[#{tag}] auth_header=#{request.headers['Authorization'].present?} " \
            "cookie_raw=#{cookies['jwt'].present?} " \
            "cookie_signed=#{cookies.signed[:jwt].present?}"
          )
        end

        def bearer_token
          request.headers['Authorization']&.split(' ')&.last
        end

        def set_default_format
          request.format = :json
        end

        def set_jwt_cookie(token, expires_at)
          cookies.signed[:jwt] = {
            value:     token,
            httponly:  true,
            secure:    true,          # required with SameSite=None
            same_site: :none,         # frontend is on a different origin
            path:      '/',
            expires:   expires_at
          }
          Rails.logger.debug "JWT cookie set to expire at #{expires_at.utc.iso8601}" if Rails.env.development?
        end

        def authenticate_amigo(amigo_params)
          unless amigo_params
            render_error('Missing login parameters', :bad_request)
            return nil
          end

          login    = amigo_params[:login_attribute].to_s.strip.downcase
          password = amigo_params[:password].to_s

          Rails.logger.debug "[LOGIN] Attempt for '#{login}'" if Rails.env.development?

          amigo = Amigo.where(
            'LOWER(email) = :login OR LOWER(user_name) = :login',
            login: login
          ).first

          if amigo.nil?
            Rails.logger.debug "[LOGIN] No account found for '#{login}'" if Rails.env.development?
            render_error('Invalid login credentials', :unauthorized)
            return nil
          end

          unless amigo.valid_password?(password)
            render_error('Invalid login credentials', :unauthorized)
            return nil
          end
          amigo
        end

        def render_error(message, status_code)
          render json: {
            status: {
              code:    Rack::Utils::SYMBOL_TO_STATUS_CODE[status_code],
              message: message
            },
            errors: [message]
          }, status: status_code
        end
      end
    end
  end
end
