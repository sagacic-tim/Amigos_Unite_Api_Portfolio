# spec/policies/event_policy_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPolicy, type: :policy do
  let!(:lead)        { create(:amigo) }
  let!(:assistant)   { create(:amigo) }
  let!(:participant) { create(:amigo) }
  let!(:outsider)    { create(:amigo) }

  # Your Amigo does not have an `admin` boolean; it appears to have a `role` enum/string.
  # This must match whatever makes `amigo.admin?` return true in your app.
  let!(:admin)       { create(:amigo, role: :admin) }

  let!(:event) { create(:event, lead_coordinator: lead) }

  before do
    # Policy role detection depends on event.event_amigo_connectors for the actor.
    create(:event_amigo_connector, :lead, event: event, amigo: lead)
    create(:event_amigo_connector, :assistant, event: event, amigo: assistant)
    create(:event_amigo_connector, :participant, event: event, amigo: participant)
  end

  def policy_for(user, record = event)
    described_class.new(user, record)
  end

  describe "top-level permissions" do
    it "create? requires a logged-in user" do
      expect(policy_for(nil).create?).to eq(false)
      expect(policy_for(outsider).create?).to eq(true)
    end

    it "show? is public" do
      expect(policy_for(nil).show?).to eq(true)
      expect(policy_for(outsider).show?).to eq(true)
    end

    it "update? is allowed for admin, lead, or assistant" do
      expect(policy_for(admin).update?).to eq(true)
      expect(policy_for(lead).update?).to eq(true)
      expect(policy_for(assistant).update?).to eq(true)

      expect(policy_for(participant).update?).to eq(false)
      expect(policy_for(outsider).update?).to eq(false)
      expect(policy_for(nil).update?).to eq(false)
    end

    it "destroy? is allowed for admin or lead only" do
      expect(policy_for(admin).destroy?).to eq(true)
      expect(policy_for(lead).destroy?).to eq(true)

      expect(policy_for(assistant).destroy?).to eq(false)
      expect(policy_for(participant).destroy?).to eq(false)
      expect(policy_for(outsider).destroy?).to eq(false)
      expect(policy_for(nil).destroy?).to eq(false)
    end
  end

  describe "connector/location management" do
    it "manage_connectors? is allowed for admin, lead, or assistant" do
      expect(policy_for(admin).manage_connectors?).to eq(true)
      expect(policy_for(lead).manage_connectors?).to eq(true)
      expect(policy_for(assistant).manage_connectors?).to eq(true)

      expect(policy_for(participant).manage_connectors?).to eq(false)
      expect(policy_for(outsider).manage_connectors?).to eq(false)
      expect(policy_for(nil).manage_connectors?).to eq(false)
    end

    it "manage_locations? mirrors manage_connectors?" do
      expect(policy_for(admin).manage_locations?).to eq(true)
      expect(policy_for(lead).manage_locations?).to eq(true)
      expect(policy_for(assistant).manage_locations?).to eq(true)

      expect(policy_for(participant).manage_locations?).to eq(false)
      expect(policy_for(outsider).manage_locations?).to eq(false)
      expect(policy_for(nil).manage_locations?).to eq(false)
    end
  end

  describe "role management" do
    it "manage_roles? is allowed for admin or lead only (not assistant)" do
      expect(policy_for(admin).manage_roles?).to eq(true)
      expect(policy_for(lead).manage_roles?).to eq(true)

      expect(policy_for(assistant).manage_roles?).to eq(false)
      expect(policy_for(participant).manage_roles?).to eq(false)
      expect(policy_for(outsider).manage_roles?).to eq(false)
      expect(policy_for(nil).manage_roles?).to eq(false)
    end
  end

  describe "nil record safety" do
    it "does not require a record for create? (record may be nil on create checks)" do
      expect(described_class.new(outsider, nil).create?).to eq(true)
      expect(described_class.new(nil, nil).create?).to eq(false)
    end
  end
end
