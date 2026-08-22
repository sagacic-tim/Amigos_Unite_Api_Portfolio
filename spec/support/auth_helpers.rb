# spec/support/auth_helpers.rb

# frozen_string_literal: true

module AuthHelpers
  def ensure_https!
    https! if respond_to?(:https!)
  end

  def csrf_path
    "/api/v1/csrf"
  end

  # Fetch CSRF token + populate the cookie jar.
  #
  # The ApplicationController requires:
  # - cookie "CSRF-TOKEN" present
  # - header "X-CSRF-Token" present
  # - both values match
  #
  # We need to:
  # 1) force HTTPS so secure cookies work
  # 2) GET /api/v1/csrf (public) to set cookie (and optionally header)
  # 3) return the token we should echo back in X-CSRF-Token
  #
  # Memoized per example instance to avoid repeated handshakes.
  def fetch_csrf_token!
    return @_csrf_token if defined?(@_csrf_token) && @_csrf_token.present?

    ensure_https!
    get csrf_path, headers: { "ACCEPT" => "application/json" }

    header_token = response.headers["X-CSRF-Token"].to_s
    cookie_token = response.cookies["CSRF-TOKEN"].to_s

    token = header_token.presence || cookie_token.presence
    raise "CSRF endpoint did not provide a CSRF token (header or cookie)" if token.blank?

    @_csrf_token = token
  end

  # JWT for Authorization header
  def jwt_for(amigo, expires_at: 12.hours.from_now)
    JsonWebToken.encode({ sub: amigo.id }, expires_at)
  end

  # Fast headers for GET requests (no CSRF handshake)
  def auth_get_headers_for(amigo)
    ensure_https!
    {
      "ACCEPT"        => "application/json",
      "Authorization" => "Bearer #{jwt_for(amigo)}"
    }
  end

  # Headers for mutating requests requiring CSRF.
  # Performs the CSRF handshake first to populate cookie jar.
  def auth_headers_for(amigo)
    csrf = fetch_csrf_token!
    {
      "ACCEPT"        => "application/json",
      "CONTENT_TYPE"  => "application/json",
      "Authorization" => "Bearer #{jwt_for(amigo)}",
      "X-CSRF-Token"  => csrf
    }
  end
end
