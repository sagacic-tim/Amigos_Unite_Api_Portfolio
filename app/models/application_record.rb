# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Logs model validation errors on save failure for easier debugging
  after_validation :log_validation_errors, if: -> { errors.any? }

  # Adds a common JSON serializer format (optional; customize as needed)
  def as_json(options = {})
    super(options.merge(except: [:created_at, :updated_at]))
  end

  private

  def log_validation_errors
    Rails.logger.warn("[Model Validation] #{self.class.name} ID: #{id || 'new record'} - Errors: #{errors.full_messages.join(', ')}")
  end
end
