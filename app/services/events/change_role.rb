# app/services/events/change_role.rb
module Events
  class ChangeRole
    # Arguments:
    # - actor:  Amigo performing the change
    # - event:  Event instance
    # - target: Amigo whose role changes
    # - new_role: :participant | :assistant_coordinator
    #
    # Usage (typical):
    #   Events::ChangeRole.call(
    #     actor: current_amigo,
    #     event: @event,
    #     target: @connector.amigo,
    #     new_role: params[:event_amigo_connector][:role]
    #   )

    # Allow both class-style and instance-style calls:
    def self.call(**kwargs)
      new.call(**kwargs)
    end

    def call(actor:, event:, target:, new_role:)
      # 1) Authorization via EventPolicy
      policy = EventPolicy.new(actor, event)
      raise NotAuthorizedError unless policy.manage_roles?

      # 2) Normalize/validate role
      role_sym = new_role.to_sym

      if role_sym == :lead_coordinator
        # Keep lead coordinator changes in the dedicated service
        raise ArgumentError, "Use Events::TransferLead for lead promotions"
      end

      # 3) Find the connector for the target amigo on this event
      conn = event.event_amigo_connectors.find_by!(amigo_id: target.id)

      # 4) Persist the role change
      conn.update!(role: role_sym)

      conn
    end
  end
end
