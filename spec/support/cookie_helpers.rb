
# spec/support/cookie_helpers.rb
# frozen_string_literal: true

module CookieHelpers
  # Returns the raw Set-Cookie header as a single string (cookies separated by newlines).
  def set_cookie_header
    raw = response.headers["Set-Cookie"]
    raw.is_a?(Array) ? raw.join("\n") : raw.to_s
  end

  # Returns an array of individual Set-Cookie lines.
  def set_cookie_lines
    header = set_cookie_header
    return [] if header.blank?
    header.split("\n")
  end

  # Returns the Set-Cookie line for a given cookie name (first match).
  def set_cookie_line_for(name)
    set_cookie_lines.find { |line| line.match?(/\A#{Regexp.escape(name)}=/i) }
  end

  # Extracts the cookie value from a Set-Cookie line (best effort).
  # Example: "jwt=abc123; path=/; ..." => "abc123"
  def cookie_value_from_set_cookie(name)
    line = set_cookie_line_for(name)
    return nil unless line

    # capture everything up to first semicolon
    line[/\A#{Regexp.escape(name)}=([^;]*)/i, 1]
  end

  # Assert cookie is present in Set-Cookie output.
  def expect_cookie_set!(name)
    expect(set_cookie_header).to match(/\A.*#{Regexp.escape(name)}=/im)
  end

  # Assert cookie is absent from Set-Cookie output.
  def expect_cookie_absent!(name)
    expect(set_cookie_header).not_to match(/\A.*#{Regexp.escape(name)}=/im)
  end

  # Assert cookie was cleared (expired) in Set-Cookie output.
  # This matches patterns like:
  #   name=; ... max-age=0 ...
  #   name=; ... expires=Thu, 01 Jan 1970 ...
  def expect_cookie_cleared!(name)
    line = set_cookie_line_for(name)
    expect(line).to be_present, "Expected #{name} to be in Set-Cookie, got:\n#{set_cookie_header}"

    expect(line).to match(/\A#{Regexp.escape(name)}=;?/i)
    expect(line).to match(/expires=|max-age=0/i)
  end

  # Assert cookie is either cleared (if present) or not mentioned at all.
  # Useful for logout when a cookie may not have existed.
  def expect_cookie_cleared_or_absent!(name)
    line = set_cookie_line_for(name)
    return if line.blank?

    expect(line).to match(/\A#{Regexp.escape(name)}=;?/i)
    expect(line).to match(/expires=|max-age=0/i)
  end

  # Optional: assert cookie contains specific attributes, scoped to that cookie line.
  def expect_cookie_attribute!(name, pattern)
    line = set_cookie_line_for(name)
    expect(line).to be_present, "Expected #{name} to be in Set-Cookie, got:\n#{set_cookie_header}"
    expect(line).to match(pattern)
  end
end

RSpec.configure do |config|
  config.include CookieHelpers, type: :request
end
