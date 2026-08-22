# spec/models/event_location_connector_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventLocationConnector, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:event_location_connector)).to be_valid
    end
  end

  describe "callbacks" do
    it "defaults status to pending" do
      c = build(:event_location_connector, status: nil)
      c.valid?
      expect(c.status).to eq("pending")
    end
  end

  describe "primary location constraint" do
    it "allows only one primary connector per event" do
      event = create(:event)

      create(:event_location_connector, :primary, event: event)
      second = build(:event_location_connector, :primary, event: event)

      expect(second).not_to be_valid
      expect(second.errors[:event_id].join).to match(/already has a primary location/i)
    end
  end
end
