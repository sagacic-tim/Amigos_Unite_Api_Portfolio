# frozen_string_literal: true

# app/models/amigo_detail.rb
class AmigoDetail < ApplicationRecord
  belongs_to :amigo

  # Permit nothing by default; selectively allow safe inline tags.
  BIO_SANITIZE_CONFIG = Sanitize::Config.merge(
    Sanitize::Config::RESTRICTED,
    elements:   %w[b i em strong br a],
    attributes: { "a" => %w[href rel target] },
    protocols:  { "a" => %w[http https mailto] }
  )

  before_validation :scrub_personal_bio
  before_validation :normalize_boolean_fields
  before_validation :convert_date_of_birth

  validates :personal_bio, length: { maximum: 2000 }, allow_nil: true
  validate  :bio_must_contain_readable_text_if_submitted
  validate  :date_of_birth_format

  private

  # Returns true if the string contains any readable (non-whitespace) text
  # after stripping *all* HTML tags.
  def readable_text?(html)
    Sanitize.fragment(html.to_s, elements: []).to_s.strip.present?
  end

  # Policy:
  # - If personal_bio is nil: treat as "not provided" and do nothing
  # - If personal_bio is blank/whitespace: allow clearing (set to "")
  # - If personal_bio is non-blank: sanitize to allowlist; must contain readable text after sanitization
  def scrub_personal_bio
    # Reset flags each validation run to avoid stale state.
    @bio_submitted = false
    @bio_readable_after_sanitize = true

    return if personal_bio.nil?

    original = personal_bio.to_s

    # Explicit clearing is allowed (bio is optional).
    if original.strip.empty?
      self.personal_bio = ""
      return
    end

    @bio_submitted = true

    cleaned = Sanitize.fragment(original, BIO_SANITIZE_CONFIG).to_s.strip
    self.personal_bio = cleaned

    @bio_readable_after_sanitize = readable_text?(cleaned)
  end

  def bio_must_contain_readable_text_if_submitted
    return unless @bio_submitted
    return if @bio_readable_after_sanitize

    errors.add(:personal_bio, "must contain readable text")
  end

  # Normalize input values to true/false/nil for boolean fields
  def normalize_boolean_fields
    %i[
      member_in_good_standing
      available_to_host
      willing_to_help
      willing_to_donate
    ].each do |field|
      self[field] = coerce_to_boolean(self[field])
    end
  end

  def coerce_to_boolean(value)
    case value.to_s.strip.downcase
    when "true", "yes", "1" then true
    when "false", "no", "0", "" then false
    else nil
    end
  end

  # Attempts to coerce date_of_birth to a proper Date object from various formats
  def convert_date_of_birth
    return if date_of_birth.is_a?(Date)

    raw_input =
      if respond_to?(:date_of_birth_before_type_cast)
        date_of_birth_before_type_cast
      else
        date_of_birth
      end.to_s.strip

    # Blank → treat as nil (optional field)
    if raw_input.blank?
      self.date_of_birth = nil
      return
    end

    formats = [
      "%m/%d/%Y", "%d/%m/%Y", "%Y/%m/%d",
      "%Y-%m-%d", "%d-%m-%Y", "%d.%m.%Y",
      "%d %B %Y", "%B %d, %Y"
    ]

    parsed = formats.lazy.map do |fmt|
      begin
        Date.strptime(raw_input, fmt)
      rescue ArgumentError
        nil
      end
    end.find(&:present?)

    if parsed
      self.date_of_birth = parsed
    else
      errors.add(
        :date_of_birth,
        "is in an unrecognized format. Expected formats include MM/DD/YYYY, DD/MM/YYYY, YYYY-MM-DD, and others."
      )
    end
  end

  # Ensures final value is a valid Date object
  def date_of_birth_format
    return if date_of_birth.nil?
    errors.add(:date_of_birth, "must be a valid date") unless date_of_birth.is_a?(Date)
  end
end
