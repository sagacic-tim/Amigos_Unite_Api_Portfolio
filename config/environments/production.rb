# config/environments/production.rb
require "active_support/core_ext/integer/time"

Rails.application.configure do
  # ── Host / URL (used by mailers, routes, etc.) ──
  host     = ENV.fetch("APP_HOST", "amigosunite.org")
  protocol = ENV.fetch("APP_PROTOCOL", "https")
  port_env = ENV["APP_PORT"]
  port     = port_env.present? ? port_env.to_i : nil

  # ── Code loading / caching ──
  config.cache_classes = true
  config.eager_load    = true

  config.consider_all_requests_local = false
  config.require_master_key          = true

  # ── Static files / storage ──
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.active_storage.service     = :local
  config.active_storage.queues.analysis = :media
  config.active_storage.queues.purge    = :media

  # ── SSL (TLS terminated by host Nginx; ensure it sets X-Forwarded-Proto=https) ──
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"

  # ── Logging ──
  config.log_level     = :info
  config.log_tags      = [:request_id]
  config.log_formatter = ::Logger::Formatter.new

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    stdout_logger           = ActiveSupport::Logger.new($stdout)
    stdout_logger.formatter = config.log_formatter
    config.logger           = ActiveSupport::TaggedLogging.new(stdout_logger)
  end

  # Boot-safe logger (do NOT use Rails.logger here)
  boot_logger = config.logger || ActiveSupport::Logger.new($stdout)

  # ── Active Job / Sidekiq ──
  config.active_job.queue_adapter = :sidekiq

  # ── URL defaults ──
  config.action_mailer.default_url_options       = { host:, protocol:, port: }
  Rails.application.routes.default_url_options   = { host:, protocol:, port: }

  # ── Cookies (SPA on another domain) ──
  config.action_dispatch.cookies_same_site_protection = :none

  # ── I18n / deprecations / schema ──
  config.i18n.fallbacks                            = true
  config.active_support.report_deprecations        = false
  config.active_record.dump_schema_after_migration = false

  # ── Action Mailer ───────────────────────────────────────────────────────────
  # Provider selection & SMTP settings are configured in:
  #   config/initializers/action_mailer.rb
  #
  # Do NOT gate delivery here on SENDGRID_API_KEY; that would disable SMTP mode.
  config.action_mailer.perform_caching = false

  # Only raise if explicitly requested (initializer decides if deliveries are enabled)
  config.action_mailer.raise_delivery_errors =
    ENV.fetch("MAIL_RAISE_DELIVERY_ERRORS", "false").to_s.strip == "true"

  # Log if SendGrid key is missing ONLY when SendGrid is selected
  if ENV.fetch("MAIL_PROVIDER", "none").to_s.strip.downcase == "sendgrid" &&
     ENV["SENDGRID_API_KEY"].to_s.strip.empty?
    boot_logger.warn("[mail] MAIL_PROVIDER=sendgrid but SENDGRID_API_KEY missing; deliveries will be disabled (production)")
  end
end
