# db/migrate/20251030043056_change_event_speakers_to_array.rb
class ChangeEventSpeakersToArray < ActiveRecord::Migration[7.1]
  def up
    # 1) Add a temporary array column with a safe default
    add_column :events, :event_speakers_performers_tmp, :text, array: true, default: [], null: false

    # 2) Populate tmp from the old column if present
    if column_exists?(:events, :event_speakers_performers)
      # 2a) Empty-ish values -> empty array
      execute <<~SQL
        UPDATE events
        SET event_speakers_performers_tmp = '{}'::text[]
        WHERE event_speakers_performers IS NULL
           OR btrim(event_speakers_performers::text) IN ('', '""', '{}');
      SQL

      # 2b) Non-empty: if it's already an array, copy it; else split CSV string
      execute <<~SQL
        UPDATE events
        SET event_speakers_performers_tmp =
          CASE
            WHEN pg_typeof(event_speakers_performers) = 'text[]'::regtype
              THEN COALESCE(event_speakers_performers, '{}'::text[])
            ELSE (
              SELECT ARRAY(
                SELECT e
                FROM unnest(
                  regexp_split_to_array(
                    -- strip accidental braces/quotes then split on commas
                    regexp_replace(event_speakers_performers::text, '^[{"]+|[}"]+$', '', 'g'),
                    '\\s*,\\s*'
                  )
                ) AS e
                WHERE btrim(e) <> ''
              )
            )
          END
        WHERE event_speakers_performers IS NOT NULL
          AND btrim(event_speakers_performers::text) NOT IN ('', '""', '{}');
      SQL

      # 3) Swap columns
      remove_column :events, :event_speakers_performers
      rename_column :events, :event_speakers_performers_tmp, :event_speakers_performers
    else
      # If original column is missing, just rename tmp into place.
      rename_column :events, :event_speakers_performers_tmp, :event_speakers_performers
    end

    # 4) Constraint (no subqueries in CHECK): disallow literal empty strings
    execute <<~SQL
      ALTER TABLE events
      ADD CONSTRAINT chk_event_speakers_no_blank
      CHECK (array_position(event_speakers_performers, '') IS NULL);
    SQL

    add_index :events, :event_speakers_performers, using: :gin, name: "idx_events_speakers_gin"
  end

  def down
    remove_index :events, name: "idx_events_speakers_gin"
    execute "ALTER TABLE events DROP CONSTRAINT IF EXISTS chk_event_speakers_no_blank"

    # Recreate the old string column and collapse array back to CSV
    add_column :events, :event_speakers_performers_tmp, :string

    execute <<~SQL
      UPDATE events
      SET event_speakers_performers_tmp =
        NULLIF(array_to_string(COALESCE(event_speakers_performers, '{}'::text[]), ', '), '');
    SQL

    remove_column :events, :event_speakers_performers
    rename_column :events, :event_speakers_performers_tmp, :event_speakers_performers
  end
end
