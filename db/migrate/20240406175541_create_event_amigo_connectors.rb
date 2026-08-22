class CreateEventAmigoConnectors < ActiveRecord::Migration[7.1]
  def change
    create_table :event_amigo_connectors do |t|
      t.references :amigo, null: false, foreign_key: true, comment: "Reference to the Amigo (user) participating in the event"
      t.references :event, null: false, foreign_key: true, comment: "Reference to the associated event"
      t.integer :role, default: 0, null: false, comment: "Role of the Amigo in the event (e.g., participant, assistant_coordinator), stored as enum"
      t.integer :status, default: 0, null: false, comment: "Status of participation (e.g., active/inactive), stored as enum"

      t.timestamps
    end
  end
end
