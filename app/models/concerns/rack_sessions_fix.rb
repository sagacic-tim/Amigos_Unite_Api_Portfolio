# app/models/concerns/rack_sessions_fix.rb
# Prevents Devise from expecting Rack session middleware in stateless API environments (e.g., JWT auth)

module RackSessionsFix
  extend ActiveSupport::Concern

  # Dummy session object to satisfy middleware expectations without enabling session behavior
  class FakeRackSession < Hash
    def enabled?
      false
    end

    def destroy
      # intentionally left blank to satisfy Devise
    end
  end

  included do
    before_action :inject_fake_session
    before_action :disable_real_session_for_devise
  end

  private

  # Prevents session errors by injecting a fake Rack session object
  def inject_fake_session
    request.env['rack.session'] ||= FakeRackSession.new
  end

  # Tells Devise to skip storing session for the request (stateless mode)
  def disable_real_session_for_devise
    request.session_options[:skip] = true
  end
end
