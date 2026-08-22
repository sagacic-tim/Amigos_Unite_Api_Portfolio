# app/controllers/concerns/error_handling.rb

module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
    rescue_from ActiveRecord::RecordNotSaved, with: :record_not_saved
    rescue_from StandardError, with: :internal_error unless Rails.env.development?
  end

  private

  def record_not_found(exception)
    Rails.logger.warn "[ErrorHandling] RecordNotFound: #{exception.message}"
    render json: { error: exception.message }, status: :not_found
  end

  def record_invalid(exception)
    Rails.logger.warn "[ErrorHandling] RecordInvalid: #{exception.record.errors.full_messages.to_sentence}"
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_content
  end

  def record_not_saved(exception)
    Rails.logger.warn "[ErrorHandling] RecordNotSaved: #{exception.message}"
    render json: { error: exception.message }, status: :unprocessable_content
  end

  def internal_error(exception)
    Rails.logger.error "[ErrorHandling] InternalError: #{exception.class.name} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
    render json: { error: "An unexpected error occurred." }, status: :internal_server_error
  end
end
