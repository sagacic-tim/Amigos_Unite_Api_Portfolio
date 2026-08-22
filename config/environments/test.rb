# config/environments/test.rb
require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = ENV["CI"].present?

  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  config.consider_all_requests_local = true

  # Rails 7.1+ deprecates boolean false here; use :none instead.
  config.action_dispatch.show_exceptions = :none

  config.action_controller.allow_forgery_protection = false

  config.active_storage.service = :test

  # URL / host for CI and tests
  host     = "localhost"
  protocol = "http"
  port     = 3001

  config.action_mailer.default_url_options = { host:, protocol:, port: }
  Rails.application.routes.default_url_options = { host:, protocol:, port: }
  config.default_url_options = { host:, protocol:, port: }

  # Jobs run inline / in test adapter
  config.active_job.queue_adapter = :test

  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = true

  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  # Keeps test output cleaner in CI
  config.log_level = :warn
end
