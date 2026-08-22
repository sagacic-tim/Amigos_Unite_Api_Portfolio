# config/initializers/custom_failure_app.rb
require_relative Rails.root.join('app', 'lib', 'custom_failure_app').to_s

Devise.setup do |config|
  config.warden do |manager|
    manager.failure_app = CustomFailureApp
  end
end
