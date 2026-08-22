class UniqueLeadPerEvent < ActiveRecord::Migration[7.1]
  def change
    # role = 2 corresponds to :lead_coordinator per EventAmigoConnector enum
    add_index :event_amigo_connectors,
             :event_id,
             unique: true,
             where: "role = 2",
             name: "uniq_lead_coordinator_per_event"
    end
end
