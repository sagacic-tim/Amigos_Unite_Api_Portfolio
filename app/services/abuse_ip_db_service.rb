# app/services/abuse_ip_db_service.rb
#
# Checks an IP address against the AbuseIPDB reputation database.
# Results are cached in Redis to stay within the free-tier limit (1,000/day).
#
# Usage:
#   AbuseIpDbService.suspicious?(ip)  # => true / false
#
class AbuseIpDbService
  include HTTParty
  base_uri 'https://api.abuseipdb.com/api/v2'

  # Cache clean IPs for 1 hour; cache bad IPs for 24 hours.
  CLEAN_TTL   = 1.hour
  BAD_TTL     = 24.hours

  # Treat scores at or above this threshold as suspicious.
  # 80 is deliberately conservative — real users rarely score above 50.
  BLOCK_THRESHOLD = 80

  # Private/loopback ranges that should never be checked or blocked.
  PRIVATE_RANGES = [
    /\A127\./,
    /\A10\./,
    /\A172\.(1[6-9]|2\d|3[01])\./,
    /\A192\.168\./,
    /\A::1\z/,
    /\Afc00:/i,
  ].freeze

  class << self
    # Returns true if the IP is known bad, false if clean or on error.
    # Fails open on API errors to avoid blocking legitimate users.
    def suspicious?(ip)
      return false if ip.blank?
      return false if private?(ip)
      return false if api_key.blank?

      cached = cache.read(cache_key(ip))
      return cached unless cached.nil?

      fetch_and_cache(ip)
    rescue StandardError => e
      Rails.logger.warn("[AbuseIPDB] Error checking #{ip}: #{e.message}")
      false # fail open
    end

    private

    def private?(ip)
      PRIVATE_RANGES.any? { |r| r.match?(ip.to_s) }
    end

    def fetch_and_cache(ip)
      response = get(
        '/check',
        headers: {
          'Key'    => api_key,
          'Accept' => 'application/json'
        },
        query: {
          ipAddress:    ip,
          maxAgeInDays: 90
        },
        timeout: 3 # seconds — don't slow down requests if API is sluggish
      )

      unless response.success?
        Rails.logger.warn("[AbuseIPDB] Non-200 response for #{ip}: #{response.code}")
        return false
      end

      score = response.dig('data', 'abuseConfidenceScore').to_i
      bad   = score >= BLOCK_THRESHOLD

      ttl = bad ? BAD_TTL : CLEAN_TTL
      cache.write(cache_key(ip), bad, expires_in: ttl)

      Rails.logger.info("[AbuseIPDB] #{ip} score=#{score} blocked=#{bad}") if bad

      bad
    end

    def cache_key(ip)
      "abuseipdb:#{ip}"
    end

    def cache
      Rails.cache
    end

    def api_key
      @api_key ||= Rails.application.credentials.dig(:abuseipdb, :api_key) ||
                   ENV['ABUSEIPDB_API_KEY']
    end
  end
end
