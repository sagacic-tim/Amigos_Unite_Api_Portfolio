# app/controllers/application_controller.rb
class ApplicationController < ActionController::API

  # Local auth error used by services/policies when Pundit is not installed.
  class NotAuthorizedError < StandardError; end

  include ActionController::MimeResponds
  include RackSessionsFix
  include Devise::Controllers::Helpers
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection
  include Authentication

  prepend_before_action :force_devise_amigo_mapping

  # Use Rails' CSRF for non-API (HTML) requests only
  protect_from_forgery with: :exception, unless: -> { api_request? }

  # Issue a CSRF token cookie for API GETs so the SPA can send it back
  before_action :set_csrf_cookie, if: -> { api_request? && request.get? }

  # Enforce CSRF for ALL mutating API calls (including signup/login)
  before_action :verify_csrf_token,
                if: -> { api_request? && request.method.in?(%w[POST PUT PATCH DELETE]) }

  # Authenticate everywhere EXCEPT our public auth endpoints
  before_action :authenticate_amigo!, unless: :auth_public_endpoint?
  helper_method :current_amigo
  respond_to :json

  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from NotAuthorizedError do
    respond_to do |format|
      format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
      format.html { head :unauthorized }
    end
  end

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found


  # --- CSRF helpers ----------------------------------------------------------

  def set_csrf_cookie
    cookies['CSRF-TOKEN'] = {
      value:     form_authenticity_token,
      same_site: :none,
      secure:    true,
      http_only: false,
      path:      '/'
    }
  end

  def verify_csrf_token
    header_token = request.headers['X-CSRF-Token'].to_s
    cookie_token = cookies['CSRF-TOKEN'].to_s

    if header_token.blank? || cookie_token.blank?
      Rails.logger.error("CSRF validation failed for request_id=#{request.request_id}")
      return render json: { error: 'Invalid CSRF token' }, status: :unauthorized
    end

    unless ActiveSupport::SecurityUtils.secure_compare(header_token, cookie_token)
      Rails.logger.error("CSRF validation failed for request_id=#{request.request_id}")
     return render json: { error: 'Invalid CSRF token' }, status: :unauthorized
    end
  end

  # --- Devise strong params --------------------------------------------------

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: %i[user_name email unformatted_phone_1 password])

    devise_parameter_sanitizer.permit(:sign_up, keys: %i[
      first_name last_name user_name email secondary_email
      unformatted_phone_1 unformatted_phone_2 avatar password password_confirmation
    ])

    devise_parameter_sanitizer.permit(:account_update, keys: %i[
      first_name last_name user_name email secondary_email
      unformatted_phone_1 unformatted_phone_2 avatar password current_password
    ])
  end

  private

  def force_devise_amigo_mapping
    if request.path.start_with?("/api/v1/") &&
       %w[signup login refresh_token logout verify_token].any? { |seg| request.path.include?(seg) }
      Rails.logger.info "[APPLICATION] forcing Devise.mapping[:amigo] for #{request.path}"
      request.env["devise.mapping"] = Devise.mappings[:amigo]
    end
  end

  def auth_public_endpoint?
    path = request.path
    path.start_with?(
      '/api/v1/csrf',
      '/api/v1/signup',
      '/api/v1/login',
      '/api/v1/refresh_token',
      '/api/v1/verify_token',
      '/api/v1/logout'
    )
  end

  def api_request?
    request.format.json? || request.path.start_with?('/api')
  end

  def filtered_headers
    # Strip sensitive headers explicitly before logging.
    sensitive = %w[
      HTTP_AUTHORIZATION Authorization
      COOKIE Cookie Set-Cookie
      X-CSRF-Token X_CSRF_TOKEN X_Csrf_Token
    ]
    request.headers.to_h.except(
      *sensitive,
      *%w[
        rack.input action_dispatch.secret_key_base
        action_dispatch.signed_cookie_salt action_dispatch.encrypted_cookie_salt
        action_dispatch.encrypted_signed_cookie_salt action_dispatch.authenticated_encrypted_cookie_salt
        action_dispatch.http_auth_salt action_dispatch.secret_token
        action_dispatch.cookies_serializer action_dispatch.encrypted_cookie_cipher
        action_dispatch.signed_cookie_cipher action_dispatch.content_security_policy
        action_dispatch.content_security_policy_nonce_directives
        action_dispatch.content_security_policy_report_only
      ]
    )
  end

  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def render_not_found
    render json: { error: 'Not found' }, status: :not_found
  end

end
