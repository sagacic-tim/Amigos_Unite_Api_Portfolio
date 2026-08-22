# config/initializers/jwt.rb

# Ensure the JWT secret is present in credentials.
jwt_secret = Rails.application.credentials.dig(:devise, :jwt_secret_key)

if jwt_secret.blank?
  raise "JWT secret key is not set in credentials. " \
        "Add devise.jwt_secret_key to the appropriate config/credentials/*.yml.enc"
end

Rails.logger.info "[JWT] Loaded Devise JWT secret key successfully."
