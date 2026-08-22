
# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventAmigoConnector, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:event_amigo_connector)).to be_valid
    end
  end

  describe "validations" do
    it "enforces uniqueness of amigo per event" do
      event = create(:event)
      amigo = create(:amigo)

      create(:event_amigo_connector, event: event, amigo: amigo, role: :participant)
      dup = build(:event_amigo_connector, event: event, amigo: amigo, role: :participant)

      expect(dup).not_to be_valid
      expect(dup.errors[:amigo_id].join).to match(/already assigned/i)
    end

    it "enforces only one lead coordinator per event" do
      event = create(:event)
      create(:event_amigo_connector, :lead, event: event, amigo: create(:amigo))

      second_lead = build(:event_amigo_connector, :lead, event: event, amigo: create(:amigo))
      expect(second_lead).not_to be_valid
      expect(second_lead.errors[:role].join).to match(/already has a lead coordinator/i)
    end
  end

  describe "callbacks" do
    it "defaults status to pending on create when nil" do
      conn = build(:event_amigo_connector, status: nil)
      conn.valid?
      expect(conn.status).to eq("pending")
    end
  end

  describe "#coordinator?" do
    it "is true for lead and assistant" do
      expect(build(:event_amigo_connector, :lead).coordinator?).to eq(true)
      expect(build(:event_amigo_connector, :assistant).coordinator?).to eq(true)
    end

    it "is false for participant" do
      expect(build(:event_amigo_connector, role: :participant).coordinator?).to eq(false)
    end
  end
end
