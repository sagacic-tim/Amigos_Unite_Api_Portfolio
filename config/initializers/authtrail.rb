# config/initializers/authtrail.rb

return if Rails.env.test?
# Enable IP geocoding
AuthTrail.geocode = true

# Transform login data to enrich logging
AuthTrail.transform_method = lambda do |data, request|
  data[:request_id] = request.request_id
  data[:user_agent] = request.user_agent
  data[:referrer] = request.referrer
  data[:ip] = request.remote_ip
  data[:context] = request.params[:controller]
  data[:scope] = 'amigo'  # Customize for Devise scope if needed
end

# Exclude test or non-human login attempts
AuthTrail.exclude_method = lambda do |data|
  data[:identity] == "capybara@example.org" || Rails.env.test?
end
