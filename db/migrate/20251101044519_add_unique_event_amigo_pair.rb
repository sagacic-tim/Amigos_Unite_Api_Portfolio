class AddUniqueEventAmigoPair < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up

    add_index :event_amigo_connectors,
              [:event_id, :amigo_id],
              unique: true,
              name: "uniq_event_amigo_per_event",
              algorithm: :concurrently
  end

  def down
    remove_index :event_amigo_connectors,
                 name: "uniq_event_amigo_per_event",
                 algorithm: :concurrently
  end
end
