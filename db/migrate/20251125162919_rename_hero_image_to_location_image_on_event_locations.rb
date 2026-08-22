# db/migrate/20251125000000_rename_hero_image_to_location_image_on_event_locations.rb
class RenameHeroImageToLocationImageOnEventLocations < ActiveRecord::Migration[7.1]
  def up
    # 1) Rename the DB column on event_locations
    if column_exists?(:event_locations, :hero_image_attribution)
      rename_column :event_locations,
                    :hero_image_attribution,
                    :location_image_attribution
    end

    # 2) Rename the Active Storage attachment name, if you have any existing
    #    data for EventLocation with an attachment named "hero_image".
    if table_exists?(:active_storage_attachments)
      execute <<~SQL.squish
        UPDATE active_storage_attachments
        SET name = 'location_image'
        WHERE name = 'hero_image'
          AND record_type = 'EventLocation'
      SQL
    end
  end

  def down
    # Reverse the changes for rollback
    if column_exists?(:event_locations, :location_image_attribution)
      rename_column :event_locations,
                    :location_image_attribution,
                    :hero_image_attribution
    end

    if table_exists?(:active_storage_attachments)
      execute <<~SQL.squish
        UPDATE active_storage_attachments
        SET name = 'hero_image'
        WHERE name = 'location_image'
          AND record_type = 'EventLocation'
      SQL
    end
  end
end
