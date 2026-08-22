
# db/migrate/20251031_add_is_primary_and_index_to_event_location_connectors.rb
class AddIsPrimaryAndIndexToEventLocationConnectors < ActiveRecord::Migration[7.1]
  # CREATE INDEX CONCURRENTLY cannot run inside a transaction
  disable_ddl_transaction!

  def up
    # 1) Add the column if it isn't there yet
    unless column_exists?(:event_location_connectors, :is_primary)
      add_column :event_location_connectors, :is_primary, :boolean, default: false, null: false
    end

    # 2) (Optional but helpful) Pre-select one row per event as primary to avoid unique violations
    #    when adding the partial unique index. Adjust strategy if you prefer a different rule.
    execute <<~SQL.squish
      WITH firsts AS (
        SELECT DISTINCT ON (event_id) id
        FROM event_location_connectors
        ORDER BY event_id, created_at ASC
      )
      UPDATE event_location_connectors
      SET is_primary = TRUE
      WHERE id IN (SELECT id FROM firsts)
        AND NOT EXISTS (
          SELECT 1 FROM event_location_connectors elc2
          WHERE elc2.event_id = event_location_connectors.event_id
            AND elc2.is_primary = TRUE
        )
    SQL

    # 3) Add the partial unique index concurrently
    add_index :event_location_connectors,
              :event_id,
              unique: true,
              where:  "is_primary = TRUE",
              name:   "uniq_primary_location_per_event",
              algorithm: :concurrently
  end

  def down
    remove_index :event_location_connectors,
                 name: "uniq_primary_location_per_event",
                 algorithm: :concurrently rescue nil

    remove_column :event_location_connectors, :is_primary if column_exists?(:event_location_connectors, :is_primary)
  end
end

