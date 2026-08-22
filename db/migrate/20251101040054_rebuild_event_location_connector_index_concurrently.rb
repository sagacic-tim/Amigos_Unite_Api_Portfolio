# db/migrate/20251031_rebuild_event_location_connector_index_concurrently.rb
class RebuildEventLocationConnectorIndexConcurrently < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Rebuild the uniq (event_id, event_location_id) index concurrently
    remove_index :event_location_connectors,
                 name: :uniq_event_location_connector,
                 algorithm: :concurrently

    add_index :event_location_connectors,
              [:event_id, :event_location_id],
              unique: true,
              name: :uniq_event_location_connector,
              algorithm: :concurrently
  end

  def down
    # Reverse (optional)
    remove_index :event_location_connectors,
                 name: :uniq_event_location_connector,
                 algorithm: :concurrently

    add_index :event_location_connectors,
              [:event_id, :event_location_id],
              unique: true,
              name: :uniq_event_location_connector
  end
end
