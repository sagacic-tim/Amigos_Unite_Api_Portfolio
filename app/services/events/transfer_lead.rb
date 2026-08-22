# app/services/events/transfer_lead.rb
# frozen_string_literal: true

module Events
  class TransferLead
    # actor must be admin or current lead
    def call(actor:, event:, new_lead:)
      policy = EventPolicy.new(actor, event)
      raise NotAuthorizedError unless policy.manage_roles?

      Event.transaction do
        e     = Event.lock.find(event.id)
        conns = e.event_amigo_connectors.lock

        current_lead = conns.find_by!(role: :lead_coordinator)
        raise "Invariant mismatch" unless current_lead.amigo_id == e.lead_coordinator_id

        # ─────────────────────────────────────────────────────────────
        # Idempotent: transferring to the same lead should not mutate roles
        # but must preserve the invariant that a lead connector exists.
        # ─────────────────────────────────────────────────────────────
        if new_lead.id.to_i == current_lead.amigo_id.to_i
          # Ensure event FK is correct (defensive)
          if e.lead_coordinator_id.to_i != new_lead.id.to_i
            e.update!(lead_coordinator_id: new_lead.id)
          end

          return current_lead
        end

        # Find or create target connector (ensure it can pass validations)
        target = conns.find_or_create_by!(amigo_id: new_lead.id) do |c|
          c.role   = :participant
          c.status = :pending if c.respond_to?(:status) && c.status.blank?
        end

        # If target exists but has no status (or invalid), normalize defensively
        if target.respond_to?(:status) && target.status.blank?
          target.update!(status: :pending)
        end

        current_lead.update!(role: :assistant_coordinator)
        target.update!(role: :lead_coordinator)
        e.update!(lead_coordinator_id: new_lead.id)

        target
      end
    end
  end
end
