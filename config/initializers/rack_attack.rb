# config/initializers/rack_attack.rb
require 'rack/attack'

# ── Cache store ──────────────────────────────────────────────────────────────
# Use Redis in production (already running for Sidekiq) so throttle counters
# survive Puma restarts and are shared across any future worker processes.
# Fall back to in-memory in development/test.
if Rails.env.production?
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0')
  )
else
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end

# ── Safelists ────────────────────────────────────────────────────────────────
# Never throttle CORS preflight or the CSRF token handshake endpoint.
Rack::Attack.safelist('allow-preflight-and-csrf') do |req|
  req.options? || req.path == '/api/v1/csrf'
end

# ── Blocklists ───────────────────────────────────────────────────────────────
# Block requests that look like automated scanners probing for common
# vulnerabilities (WordPress, PHP, .env, git, etc.). These have no
# legitimate place on a Rails API.
SCANNER_PATHS = %w[
  /wp-admin /wp-login /wp-content /xmlrpc.php
  /.env /.git /.DS_Store
  /etc/passwd /proc/self
  /phpmyadmin /pma /myadmin
  /cgi-bin /shell /cmd
  /actuator /console /manager
].freeze

Rack::Attack.blocklist('block-scanner-paths') do |req|
  SCANNER_PATHS.any? { |path| req.path.downcase.start_with?(path) }
end

# Block IPs with a high abuse confidence score from AbuseIPDB.
# Results are cached in Redis so we stay within the free-tier limit (1,000/day).
# Fails open — if the API is unreachable, the request is allowed through.
Rack::Attack.blocklist('block-abusive-ips') do |req|
  AbuseIpDbService.suspicious?(req.ip)
end

# ── Throttles ────────────────────────────────────────────────────────────────

# 1. General API rate limit — broad protection against any single IP
#    hammering the API. 300 requests/minute is generous for real users.
Rack::Attack.throttle('api/ip', limit: 300, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/api/')
end

# 2. Login by IP — prevents brute-force from a single IP
Rack::Attack.throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
  req.ip if req.post? && req.path == '/api/v1/login'
end

# 3. Login by credential — catches distributed stuffing across many IPs
#    targeting the same account.
Rack::Attack.throttle('logins/login_attribute', limit: 5, period: 60.seconds) do |req|
  next unless req.post? && req.path == '/api/v1/login'
  begin
    raw  = req.body.read
    data = JSON.parse(raw) rescue {}
    (data.dig('amigo', 'login_attribute') || '').downcase.presence
  ensure
    req.body.rewind
  end
end

# 4. Signup by IP — prevents mass account creation
Rack::Attack.throttle('signups/ip', limit: 3, period: 10.minutes) do |req|
  req.ip if req.post? && req.path == '/api/v1/signup'
end

# 5. Password reset by IP — prevents user enumeration via reset flood
Rack::Attack.throttle('password_reset/ip', limit: 5, period: 10.minutes) do |req|
  req.ip if req.post? && req.path.include?('password')
end

# ── Throttled response ───────────────────────────────────────────────────────
# Return a proper 429 JSON response. The CORS origin is read from env vars
# so it works correctly in both dev and production.
Rack::Attack.throttled_responder = lambda do |request|
  match      = request.env['rack.attack.match_data'] || {}
  retry_after = match[:period] || 60

  fe_protocol = ENV.fetch('FRONTEND_PROTOCOL') { ENV.fetch('APP_PROTOCOL', 'https') }
  fe_host     = ENV.fetch('FRONTEND_HOST', 'localhost')
  fe_port     = ENV.fetch('FRONTEND_PORT', '5173')
  cors_origin = ENV.fetch('FRONTEND_ORIGIN', "#{fe_protocol}://#{fe_host}:#{fe_port}")

  [
    429,
    {
      'Content-Type'                     => 'application/json',
      'Retry-After'                      => retry_after.to_s,
      'Access-Control-Allow-Origin'      => cors_origin,
      'Access-Control-Allow-Credentials' => 'true'
    },
    [{ error: 'Too many requests. Please slow down.' }.to_json]
  ]
end
