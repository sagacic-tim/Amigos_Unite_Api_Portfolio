# app/jobs/process_image_job.rb
class ProcessImageJob < ApplicationJob
  queue_as :media

  def perform(event_location_id)
    event_location = EventLocation.find_by(id: event_location_id)

    unless event_location
      Rails.logger.warn("[ProcessImageJob] EventLocation not found: ID #{event_location_id}")
      return
    end

    unless event_location.location_image.attached?
      Rails.logger.warn("[ProcessImageJob] No image attached for EventLocation ID #{event_location.id}")
      return
    end

    begin
      variant = event_location.location_image.variant(resize: "640x480").processed

      variant.open do |file|
        event_location.location_image.attach(
          io: file,
          filename: event_location.location_image.filename.to_s,
          content_type: event_location.location_image.content_type
        )
      end

      Rails.logger.info("[ProcessImageJob] Image resized and re-attached for EventLocation ID #{event_location.id}")

    rescue => e
      Rails.logger.error("[ProcessImageJob] Failed to process image for EventLocation ID #{event_location.id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end
end
