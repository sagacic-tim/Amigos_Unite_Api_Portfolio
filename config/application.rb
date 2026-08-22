# config/application.rb
require_relative "boot"

# For API-only apps we can load just what we need, or keep rails/all.
# api_only slims the middleware stack.
require "rails/all"

Bundler.require(*Rails.groups)

module AmigosUniteApi
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true

    # ------------------------------------------------------------------
    # Cookies & Session (required for CSRF)
    # ------------------------------------------------------------------
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use(
      ActionDispatch::Session::CookieStore,
      key:       "_amigos_unite_session",
      same_site: :none,  # cross-site SPA <-> API
      secure:    true,   # HTTPS on both https://localhost and production
      httponly:  true,
      path:      "/"
    )

    # ------------------------------------------------------------------
    # CORS
    # ------------------------------------------------------------------
    # CORS is configured in config/initializers/cors.rb

    # ------------------------------------------------------------------
    # Rack::Attack – only in non-test environments
    # ------------------------------------------------------------------
    unless Rails.env.test?
      begin
        # Prefer inserting early so Rack::Attack can short-circuit requests
        config.middleware.insert_before Rack::Runtime, Rack::Attack
      rescue
        # In case Rack::Runtime isn't present in the stack (API-only tweaks),
        # fall back to simply adding Rack::Attack.
        config.middleware.use Rack::Attack
      end
    end

    # ------------------------------------------------------------------
    # Devise / Warden
    # ------------------------------------------------------------------
    # devise-jwt hooks into Warden automatically; you do NOT need:
    # config.middleware.use Warden::JWTAuth::Middleware

    # ------------------------------------------------------------------
    # Serializers
    # ------------------------------------------------------------------
    ActiveModelSerializers.config.adapter = :json_api

    # ------------------------------------------------------------------
    # Autoload / eager-load paths
    # ------------------------------------------------------------------
    # e.g., app/lib/json_web_token.rb
    config.autoload_paths << Rails.root.join("app/lib")
    config.eager_load_paths << Rails.root.join("app/lib")

    # ------------------------------------------------------------------
    # Active Job
    # ------------------------------------------------------------------
    # Default adapter. Overridden per-environment where needed:
    # - test.rb: :test
    # - development.rb / production.rb: :sidekiq
    config.active_job.queue_adapter = :sidekiq
  end
end
