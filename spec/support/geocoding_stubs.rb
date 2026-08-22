
# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    # Prevent external calls in any spec that happens to touch these models
    allow_any_instance_of(EventLocation).to receive(:geocode_with_fallback)
    allow_any_instance_of(EventLocation).to receive(:fetch_time_zone)

    allow_any_instance_of(AmigoLocation).to receive(:geocode_with_fallback)
    allow_any_instance_of(AmigoLocation).to receive(:fetch_time_zone)
  end
end
