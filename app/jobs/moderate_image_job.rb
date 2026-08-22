# app/jobs/moderate_image_job.rb
#
# Checks an attached image against Google Cloud Vision SafeSearch after upload.
# If the image fails moderation it is purged automatically and the record owner
# receives an email notification.
#
# Usage:
#   ModerateImageJob.perform_later('Amigo', amigo.id, :avatar)
#   ModerateImageJob.perform_later('EventLocation', location.id, :location_image)
#
class ModerateImageJob < ApplicationJob
  queue_as :media

  # model_class_name — string, e.g. 'Amigo', 'EventLocation'
  # record_id        — integer primary key
  # attachment_name  — symbol or string, e.g. :avatar, :location_image
  def perform(model_class_name, record_id, attachment_name)
    model_class = model_class_name.constantize
    record      = model_class.find_by(id: record_id)

    unless record
      Rails.logger.warn("[ModerateImageJob] #{model_class_name} ##{record_id} not found — skipping")
      return
    end

    attachment = record.public_send(attachment_name)

    unless attachment.attached?
      Rails.logger.info("[ModerateImageJob] No attachment on #{model_class_name} ##{record_id}:#{attachment_name} — skipping")
      return
    end

    blob = attachment.blob

    if VisionModerationService.safe?(blob)
      Rails.logger.info("[ModerateImageJob] #{model_class_name} ##{record_id}:#{attachment_name} passed moderation")
      return
    end

    # Image failed — purge it and notify the record owner if possible
    Rails.logger.warn(
      "[ModerateImageJob] PURGING #{model_class_name} ##{record_id}:#{attachment_name} — failed Vision SafeSearch"
    )

    attachment.purge

    notify_owner(record, attachment_name)
  end

  private

  def notify_owner(record, attachment_name)
    # Resolve the amigo to notify — works for Amigo directly, or via
    # an association (e.g. EventLocation belongs_to :amigo or :event -> :amigo)
    amigo = case record
            when Amigo
              record
            else
              record.try(:amigo) || record.try(:event)&.try(:amigo)
            end

    return unless amigo&.email.present?

    ModerationMailer.image_removed(amigo, attachment_name.to_s).deliver_later
  rescue StandardError => e
    # Don't let a mailer failure prevent the purge from being logged
    Rails.logger.warn("[ModerateImageJob] Could not notify owner: #{e.message}")
  end
end
