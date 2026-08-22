class EventLocationConnectorIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :event_location_connectors,
              [:event_id, :event_location_id],
              unique: true,
              name: :uniq_event_location_connector
  end
end
