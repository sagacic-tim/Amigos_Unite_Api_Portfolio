class CreateEventLocationConnectors < ActiveRecord::Migration[7.1]
  def change
    create_table :event_location_connectors do |t|
      t.references :event, null: false, foreign_key: true, comment: "Reference to the associated event"
      t.references :event_location, null: false, foreign_key: true, comment: "Reference to the physical location where the event is held"
      t.integer :status, default: 0, null: false, comment: "Status of the connector (e.g., active/inactive), stored as enum"

      t.timestamps
    end
  end
end
