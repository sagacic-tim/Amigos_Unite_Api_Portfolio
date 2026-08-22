# spec/services/events/transfer_lead_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::TransferLead, type: :service do
  let!(:old_lead) { create(:amigo) }
  let!(:new_lead) { create(:amigo) }
  let!(:event)    { create(:event, lead_coordinator: old_lead) }

  before do
    # Ensure we start with a consistent baseline in the join table:
    # one lead_coordinator connector for the event's lead.
    create(
      :event_amigo_connector,
      event: event,
      amigo: old_lead,
      role: :lead_coordinator
    )
  end

  # ---------------------------------------------------------------------------
  # Signature-tolerant invoker
  # ---------------------------------------------------------------------------

  def call_service(event:, actor:, old_lead:, new_lead:)
    receiver =
      if described_class.respond_to?(:call)
        described_class
      else
        described_class.new
      end

    method = receiver.method(:call)
    params = method.parameters

    args = []
    kwargs = {}

    params.each do |kind, name|
      value = value_for_param(name, event: event, actor: actor, old_lead: old_lead, new_lead: new_lead)

      case kind
      when :req, :opt
        args << value
      when :keyreq, :key
        kwargs[name] = value
      when :rest, :keyrest
        # do nothing
      end
    end

    params.each do |kind, name|
      next unless kind == :keyreq
      if !kwargs.key?(name) || kwargs[name].nil?
        raise ArgumentError, "Events::TransferLead#call requires :#{name}, but spec invoker could not infer it. " \
                             "Update value_for_param to map that keyword."
      end
    end

    kwargs.any? ? method.call(*args, **kwargs) : method.call(*args)
  end

  def value_for_param(name, event:, actor:, old_lead:, new_lead:)
    case name
      when :event
        event
      when :event_id
        event.id
      when :actor, :current_amigo, :amigo
        actor
      when :old_lead, :from_lead, :previous_lead, :existing_lead
        old_lead
      when :old_lead_id, :from_lead_id, :previous_lead_id, :existing_lead_id
        old_lead.id
      when :new_lead, :to_lead, :incoming_lead, :lead
        new_lead
      when :new_lead_id, :to_lead_id, :incoming_lead_id
        new_lead.id
      when :new_lead_coordinator_id, :lead_coordinator_id
        new_lead.id
    else
      name.to_s.end_with?("_id") ? new_lead.id : nil
    end
  end

  # ---------------------------------------------------------------------------
  # Expectations
  # ---------------------------------------------------------------------------

  def lead_connector_ids_for(event)
    event.event_amigo_connectors.lead_coordinator.pluck(:amigo_id)
  end

  describe "#call" do
    it "updates event.lead_coordinator_id and makes the new lead the sole lead connector" do
      actor = old_lead

      call_service(event: event, actor: actor, old_lead: old_lead, new_lead: new_lead)

      event.reload

      expect(event.lead_coordinator_id).to eq(new_lead.id)
      expect(lead_connector_ids_for(event)).to eq([new_lead.id])

      expect(
        event.event_amigo_connectors.where(amigo_id: old_lead.id, role: "lead_coordinator")
      ).to be_empty
    end

    it "promotes an existing connector for the new lead (no duplicate connectors)" do
      actor = old_lead

      # Avoid trait drift; make the role explicit.
      create(
        :event_amigo_connector,
        event: event,
        amigo: new_lead,
        role: :assistant_coordinator
      )

      expect(event.event_amigo_connectors.where(amigo_id: new_lead.id).count).to eq(1)

      call_service(event: event, actor: actor, old_lead: old_lead, new_lead: new_lead)

      event.reload

      expect(event.lead_coordinator_id).to eq(new_lead.id)

      expect(event.event_amigo_connectors.where(amigo_id: new_lead.id).count).to eq(1)
      expect(event.event_amigo_connectors.find_by(amigo_id: new_lead.id).role).to eq("lead_coordinator")

      expect(lead_connector_ids_for(event)).to eq([new_lead.id])
    end

    it "is idempotent when transferring to the same lead (does not duplicate connectors)" do
      actor = old_lead

      expect(event.lead_coordinator_id).to eq(old_lead.id)
      expect(lead_connector_ids_for(event)).to eq([old_lead.id])

      call_service(event: event, actor: actor, old_lead: old_lead, new_lead: old_lead)

      event.reload

      expect(event.lead_coordinator_id).to eq(old_lead.id)
      expect(lead_connector_ids_for(event)).to eq([old_lead.id])
      expect(event.event_amigo_connectors.where(amigo_id: old_lead.id, role: "lead_coordinator").count).to eq(1)
    end
  end
end
