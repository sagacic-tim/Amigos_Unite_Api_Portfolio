# app/lib/custom_failure_app.rb
class CustomFailureApp < Devise::FailureApp
  def respond
    if request_format == :json || request.path.start_with?('/api/')
      log_failure
      json_api_error_response
    else
      super
    end
  end

  private

  def json_api_error_response
    self.status = 401
    self.content_type = 'application/json'
    self.response_body = {
      error: 'Authentication failed',
      path: request.fullpath,
      method: request.request_method
    }.to_json
  end

  def log_failure
    Rails.logger.warn "[CustomFailureApp] Authentication failed for path: #{request.fullpath}, method: #{request.request_method}"
  end
end
