# db/migrate/20251124233752_add_places_fields_to_event_locations.rb
class AddPlacesFieldsToEventLocations < ActiveRecord::Migration[7.1]
  def up
    # New fields for Places integration and richer venue metadata

    unless column_exists?(:event_locations, :place_id)
      add_column :event_locations, :place_id, :string,
                 comment: "Google Places place_id"
    end

    unless column_exists?(:event_locations, :capacity)
      add_column :event_locations, :capacity, :integer,
                 comment: "Approximate seating capacity"
    end

    # availability_notes already exists in your DB; just ensure the comment is set
    if column_exists?(:event_locations, :availability_notes)
      change_column_comment :event_locations,
                            :availability_notes,
                            "Free-form notes about when the venue is available"
    end

    unless column_exists?(:event_locations, :owner_name)
      add_column :event_locations, :owner_name, :string,
                 limit: 128,
                 comment: "Owner or main contact for the venue"
    end

    unless column_exists?(:event_locations, :services)
      add_column :event_locations, :services, :jsonb,
                 default: {},
                 null: false,
                 comment: "JSON hash of boolean flags, e.g. { food: true, internet: true }"
    end

    unless column_exists?(:event_locations, :hero_image_attribution)
      add_column :event_locations, :hero_image_attribution, :text,
                 comment: "Required photo attribution from Google Places"
    end

    unless index_exists?(:event_locations, :place_id)
      add_index :event_locations, :place_id
    end
  end

  def down
    # Rollback is defensive: only remove what we added

    if index_exists?(:event_locations, :place_id)
      remove_index :event_locations, :place_id
    end

    remove_column :event_locations, :hero_image_attribution if column_exists?(:event_locations, :hero_image_attribution)
    remove_column :event_locations, :services               if column_exists?(:event_locations, :services)
    remove_column :event_locations, :owner_phone            if column_exists?(:event_locations, :owner_phone)
    remove_column :event_locations, :owner_name             if column_exists?(:event_locations, :owner_name)
    remove_column :event_locations, :capacity               if column_exists?(:event_locations, :capacity)
    remove_column :event_locations, :place_id               if column_exists?(:event_locations, :place_id)

    # Do NOT drop availability_notes here; it existed before this migration.
    # If you ever need to remove it, do that in a separate, explicit migration.
  end
end
