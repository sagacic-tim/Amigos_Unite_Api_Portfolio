# app/services/vision_moderation_service.rb
#
# Checks an image blob against Google Cloud Vision SafeSearch.
# Returns true if the image is safe, false if it should be rejected.
#
# SafeSearch scores each image across five categories:
#   adult, spoof, medical, violence, racy
# Each category gets a likelihood value:
#   UNKNOWN, VERY_UNLIKELY, UNLIKELY, POSSIBLE, LIKELY, VERY_LIKELY
#
# We reject on LIKELY or VERY_LIKELY for adult or violence.
# Racy is flagged at VERY_LIKELY only (profile pics, event art can be suggestive).
#
# Usage:
#   VisionModerationService.safe?(blob)  # => true / false
#
class VisionModerationService
  # Likelihoods ranked lowest → highest. We reject at index >= REJECT_AT.
  LIKELIHOOD_RANK = %w[UNKNOWN VERY_UNLIKELY UNLIKELY POSSIBLE LIKELY VERY_LIKELY].freeze
  REJECT_AT       = LIKELIHOOD_RANK.index('LIKELY')

  # Racy content is held to a stricter threshold (only reject VERY_LIKELY).
  RACY_REJECT_AT  = LIKELIHOOD_RANK.index('VERY_LIKELY')

  class << self
    # Returns true if the image passes moderation, false if it should be purged.
    # Fails open — if Vision is unavailable the image is allowed through.
    def safe?(blob)
      return true unless enabled?

      image_bytes = download_blob(blob)
      return true if image_bytes.nil?

      annotate(image_bytes)
    rescue StandardError => e
      Rails.logger.warn("[VisionModeration] Error checking blob #{blob.id}: #{e.message}")
      true # fail open — don't delete images due to API outage
    end

    private

    def enabled?
      credentials_present = Rails.application.credentials.dig(:google_cloud, :vision_credentials).present? ||
                            ENV['GOOGLE_CLOUD_CREDENTIALS'].present? ||
                            ENV['GOOGLE_APPLICATION_CREDENTIALS'].present?
      unless credentials_present
        Rails.logger.debug('[VisionModeration] No credentials configured — skipping moderation')
      end
      credentials_present
    end

    def download_blob(blob)
      blob.open { |file| file.read }
    rescue StandardError => e
      Rails.logger.warn("[VisionModeration] Could not download blob #{blob.id}: #{e.message}")
      nil
    end

    def annotate(image_bytes)
      client   = image_annotator_client
      image    = { content: image_bytes }
      response = client.safe_search_detection(image: image)
      annotation = response.responses.first&.safe_search_annotation

      return true if annotation.nil?

      adult    = rank(annotation.adult.to_s)
      violence = rank(annotation.violence.to_s)
      racy     = rank(annotation.racy.to_s)

      adult_safe    = adult    < REJECT_AT
      violence_safe = violence < REJECT_AT
      racy_safe     = racy     < RACY_REJECT_AT

      safe = adult_safe && violence_safe && racy_safe

      unless safe
        Rails.logger.warn(
          "[VisionModeration] Image REJECTED — " \
          "adult=#{annotation.adult} violence=#{annotation.violence} racy=#{annotation.racy}"
        )
      end

      safe
    end

    def rank(likelihood_string)
      LIKELIHOOD_RANK.index(likelihood_string) || 0
    end

    def image_annotator_client
      credentials = Rails.application.credentials.dig(:google_cloud, :vision_credentials) ||
                    ENV['GOOGLE_CLOUD_CREDENTIALS']

      if credentials.present?
        # Credentials stored as JSON string (in Rails credentials or env var)
        parsed = JSON.parse(credentials)
        Google::Cloud::Vision.image_annotator do |config|
          config.credentials = parsed
        end
      else
        # Fall back to GOOGLE_APPLICATION_CREDENTIALS file path (set in env)
        Google::Cloud::Vision.image_annotator
      end
    end
  end
end
