# config/initializers/devise.rb #

Devise.setup do |config|
  # Mailer configuration
  config.mailer_sender = "no-replies@amigosunite.org"
  config.mailer = "DeviseMailer"
  config.parent_mailer = "ApplicationMailer"

  # ORM
  require "devise/orm/active_record"

  # Authentication – using virtual login_attribute on Amigo
  config.authentication_keys   = [:login_attribute]
  config.case_insensitive_keys = [:login_attribute]
  config.strip_whitespace_keys = [:login_attribute]

  # API-style: don't store sessions for these auth strategies
  config.skip_session_storage = [:http_auth, :token_auth]

  # BCrypt cost – lowered for test (good for CI speed)
  config.stretches = Rails.env.test? ? 1 : 12

  # Confirmable / passwords
  config.reconfirmable = true
  config.password_length = 10..64
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.timeout_in = 2.hours

  # Lockable
  config.lock_strategy      = :failed_attempts
  config.unlock_strategy    = :time
  config.maximum_attempts   = 5
  config.unlock_in          = 15.minutes

  # Formats (API + SPA)
  config.navigational_formats = ["*/*", :html, :json]
  config.scoped_views = true
  config.sign_out_via = :delete

  # Notifications
  config.send_email_changed_notification  = true
  config.send_password_change_notification = true


  # ─────────────────────────────────────────────
  # JWT configuration (devise-jwt)
  # ─────────────────────────────────────────────
  jwt_secret =
    Rails.application.credentials.dig(:devise, :jwt_secret_key) ||
    ENV["DEVISE_JWT_SECRET_KEY"]

  if jwt_secret.blank?
    message = "[Devise/JWT] Missing JWT secret key. " \
              "Set devise.jwt_secret_key in credentials " \
              "or DEVISE_JWT_SECRET_KEY in the environment."

    if Rails.env.test?
      # In test/CI we allow a fallback so the suite can still run.
      Rails.logger.warn(message)
      jwt_secret = "test-fallback-jwt-secret-change-me"
    else
      # In non-test environments we fail fast.
      Rails.logger.error(message)
      raise "Devise JWT secret key is not configured"
    end
  end

  config.jwt do |jwt|
    jwt.secret = jwt_secret

    # Issue token on login
    jwt.dispatch_requests = [
      ["POST", %r{^/api/v1/login$}]
    ]

    # Revoke/blacklist token on logout
    jwt.revocation_requests = [
      ["DELETE", %r{^/api/v1/logout$}]
    ]

    jwt.expiration_time = 2.hours.to_i
    jwt.request_formats  = { amigo: [:json] }
  end

  # Pepper – used as an additional secret in password hashing
  config.pepper =
    Rails.application.credentials.dig(:devise, :pepper) ||
    ENV["DEVISE_PEPPER"]

  # Custom failure app for JSON errors instead of redirects
  config.warden do |manager|
    manager.failure_app = CustomFailureApp
  end
end

