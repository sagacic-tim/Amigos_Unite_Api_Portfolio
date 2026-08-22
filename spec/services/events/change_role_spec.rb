
# spec/services/events/change_role_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::ChangeRole, type: :service do
  describe ".call" do
    it "delegates to an instance call" do
      # Smoke test that class-style call is wired
      actor  = create(:amigo)
      event  = create(:event, lead_coordinator: actor)
      target = create(:amigo)

      create(:event_amigo_connector, :lead, event: event, amigo: actor)
      create(:event_amigo_connector, :participant, event: event, amigo: target)

      conn = described_class.call(actor: actor, event: event, target: target, new_role: :assistant_coordinator)
      expect(conn).to be_a(EventAmigoConnector)
    end
  end

  describe "#call" do
    let!(:actor)  { create(:amigo) }
    let!(:event)  { create(:event, lead_coordinator: actor) }
    let!(:target) { create(:amigo) }

    before do
      # Minimum wiring for policy expectations: actor is the lead
      create(:event_amigo_connector, :lead, event: event, amigo: actor)

      # Target is already on event (service requires it)
      create(:event_amigo_connector, :participant, event: event, amigo: target)
    end

    it "updates the target connector role to assistant_coordinator" do
      conn = described_class.new.call(
        actor: actor,
        event: event,
        target: target,
        new_role: :assistant_coordinator
      )

      expect(conn).to be_present
      expect(conn.event_id).to eq(event.id)
      expect(conn.amigo_id).to eq(target.id)
      expect(conn.role).to eq("assistant_coordinator")
      expect(conn.reload.role).to eq("assistant_coordinator")
    end

    it "updates the target connector role back to participant (idempotent-friendly)" do
      # Move to assistant first
      described_class.new.call(actor: actor, event: event, target: target, new_role: :assistant_coordinator)

      conn = described_class.new.call(
        actor: actor,
        event: event,
        target: target,
        new_role: "participant"
      )

      expect(conn.role).to eq("participant")
      expect(conn.reload.role).to eq("participant")
    end

    it "raises ArgumentError if asked to set lead_coordinator (must use TransferLead)" do
      expect do
        described_class.new.call(
          actor: actor,
          event: event,
          target: target,
          new_role: :lead_coordinator
        )
      end.to raise_error(ArgumentError, /TransferLead/i)
    end

    it "raises NotAuthorizedError when actor is not allowed to manage roles" do
      outsider = create(:amigo)

      expect do
        described_class.new.call(
          actor: outsider,
          event: event,
          target: target,
          new_role: :assistant_coordinator
        )
      end.to raise_error(NotAuthorizedError)
    end

    it "raises ActiveRecord::RecordNotFound if the target is not connected to the event" do
      not_joined = create(:amigo)

      expect do
        described_class.new.call(
          actor: actor,
          event: event,
          target: not_joined,
          new_role: :assistant_coordinator
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
