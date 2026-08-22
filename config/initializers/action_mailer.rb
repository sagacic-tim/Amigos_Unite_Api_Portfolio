# config/initializers/action_mailer.rb

Rails.application.configure do
  # Boot-safe logger: Rails.logger may not be initialized yet here.
  boot_logger =
    if config.respond_to?(:logger) && config.logger
      config.logger
    else
      ActiveSupport::Logger.new($stdout)
    end

  config.action_mailer.logger = boot_logger

  # --- Dev/Test env-file loader (so bin/rails runner works without Foreman/bin/dev) ---
  def load_env_file!(path, boot_logger:)
    return unless path && File.file?(path)

    File.foreach(path) do |raw|
      line = raw.strip
      next if line.empty? || line.start_with?("#")

      # allow optional leading "export "
      line = line.sub(/\Aexport\s+/, "")

      # KEY=VALUE (VALUE may be quoted)
      m = line.match(/\A([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/)
      next unless m

      key = m[1]
      val = m[2].to_s.strip

      # Strip surrounding quotes (single or double)
      if (val.start_with?("'") && val.end_with?("'")) || (val.start_with?('"') && val.end_with?('"'))
        val = val[1..-2]
      end

      # Do not overwrite existing env
      ENV[key] = val unless ENV.key?(key)
    end

    boot_logger.info("[mail] loaded env file #{path} (non-overriding) env=#{Rails.env}")
  rescue => e
    boot_logger.warn("[mail] failed to load env file #{path}: #{e.class}: #{e.message}")
  end

  # Load env file only to support development ergonomics.
  # In test/CI, we deliberately avoid relying on ~/.secrets to prevent SMTP leakage.
  if Rails.env.development?
    secrets_path = ENV["SECRETS_FILE"].to_s.strip
    secrets_path = File.expand_path("~/.secrets/amigos_unite_api.env") if secrets_path.empty?
    load_env_file!(secrets_path, boot_logger:)
  end

  # ───────────────────────────────────────────────────────────────────────────
  # HARD GUARDBAND: tests (and CI) must use :test delivery so deliveries[] works
  # ───────────────────────────────────────────────────────────────────────────
  if Rails.env.test? || ENV["CI"].present?
    config.action_mailer.delivery_method = :test
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = false
    boot_logger.info("[mail] test/CI detected; forcing ActionMailer :test delivery env=#{Rails.env} pid=#{Process.pid}")
    return
  end

  # --- Provider selection ---
  # In production, default to SMTP (Hostinger) unless explicitly set to sendgrid/none.
  provider_default = Rails.env.production? ? "smtp" : "none"
  provider = ENV.fetch("MAIL_PROVIDER", provider_default).to_s.strip.downcase

  # Defaults: safe (no delivery unless configured)
  config.action_mailer.perform_deliveries = false
  config.action_mailer.raise_delivery_errors =
    ENV.fetch("MAIL_RAISE_DELIVERY_ERRORS", "false").to_s.strip == "true"

  case provider
  when "smtp"
    smtp_host = ENV["SMTP_HOST"].to_s.strip
    smtp_port = ENV.fetch("SMTP_PORT", "587").to_i
    smtp_user = ENV["SMTP_USERNAME"].to_s.strip
    smtp_pass = ENV["SMTP_PASSWORD"].to_s # do not strip; spaces could be intentional

    missing = []
    missing << "SMTP_HOST"     if smtp_host.empty?
    missing << "SMTP_USERNAME" if smtp_user.empty?
    missing << "SMTP_PASSWORD" if smtp_pass.empty?

    if missing.any?
      boot_logger.warn("[mail] MAIL_PROVIDER=smtp but missing #{missing.join(", ")}; deliveries disabled env=#{Rails.env}")
    else
      # Correct TLS behavior:
      # - Port 465: implicit TLS => ssl: true, enable_starttls_auto: false
      # - Port 587: STARTTLS => enable_starttls_auto: true
      implicit_tls = (smtp_port == 465)

      config.action_mailer.delivery_method = :smtp
      config.action_mailer.perform_deliveries = true

      config.action_mailer.smtp_settings = {
        address: smtp_host,
        port: smtp_port,
        domain: ENV.fetch("MAILER_DOMAIN", ENV.fetch("APP_HOST", "localhost")),
        user_name: smtp_user,
        password: smtp_pass,
        authentication: ENV.fetch("SMTP_AUTH", "login").to_sym,
        ssl: implicit_tls,
        enable_starttls_auto: implicit_tls ? false : (ENV.fetch("SMTP_STARTTLS", "true").to_s.strip == "true"),
        open_timeout: 15,
        read_timeout: 20
      }

      boot_logger.info("[mail] SMTP configured host=#{smtp_host} port=#{smtp_port} ssl=#{implicit_tls} env=#{Rails.env} pid=#{Process.pid}")
    end

  when "sendgrid"
    sendgrid_key = ENV["SENDGRID_API_KEY"].to_s.strip
    if sendgrid_key.empty?
      boot_logger.warn("[mail] MAIL_PROVIDER=sendgrid but SENDGRID_API_KEY missing; deliveries disabled env=#{Rails.env}")
    else
      config.action_mailer.delivery_method = :smtp
      config.action_mailer.perform_deliveries = true

      config.action_mailer.smtp_settings = {
        address: "smtp.sendgrid.net",
        port: 587,
        domain: ENV.fetch("MAILER_DOMAIN", ENV.fetch("APP_HOST", "localhost")),
        user_name: "apikey",
        password: sendgrid_key,
        authentication: :plain,
        enable_starttls_auto: true,
        open_timeout: 15,
        read_timeout: 20
      }

      boot_logger.info("[mail] SendGrid SMTP configured env=#{Rails.env} pid=#{Process.pid}")
    end

  else
    boot_logger.warn("[mail] MAIL_PROVIDER=#{provider}; email delivery disabled env=#{Rails.env} pid=#{Process.pid}")
  end
end
