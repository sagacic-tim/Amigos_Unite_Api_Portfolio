# config/inigtializers/core.rb

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Build the frontend origin from env vars so the same code works in
    # dev (http or https) and production without changes.
    fe_protocol = ENV.fetch("FRONTEND_PROTOCOL") { ENV.fetch("APP_PROTOCOL", "https") }
    fe_host     = ENV.fetch("FRONTEND_HOST", "localhost")
    fe_port     = ENV.fetch("FRONTEND_PORT", "5173")
    fe_origin   = "#{fe_protocol}://#{fe_host}:#{fe_port}"

    # In production the frontend is served from the main domain
    prod_origin = ENV["FRONTEND_ORIGIN"] # e.g. "https://amigosunite.org"

    allowed = [fe_origin, prod_origin].compact

    origins(*allowed)

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      expose: ['Authorization', 'Set-Cookie', 'X-CSRF-Token'],
      credentials: true
  end
end
