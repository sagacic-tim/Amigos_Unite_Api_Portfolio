class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.string :event_name, comment: "Name of the event (e.g., Annual Meetup)"
      t.string :event_type, comment: "Type of event (e.g., Workshop, Seminar, Concert)"
      t.string :event_speakers_performers, array: true, default: [], comment: "List of speakers or performers for the event"
      t.date :event_date, comment: "Date on which the event will be held"
      t.time :event_time, comment: "Time of day the event is scheduled to start"
      
      # Add a reference to the event coordinator (an Amigo)
      t.bigint :lead_coordinator_id, null: false, comment: "Amigo ID of the event's lead coordinator"
      
      t.integer :status, default: 0, null: false, comment: "Event status (e.g., pendiong, verified, rejected) represented as enum"

      t.timestamps
    end

    # Add a foreign key constraint to ensure data integrity
    add_foreign_key :events, :amigos, column: :lead_coordinator_id
  end
end
