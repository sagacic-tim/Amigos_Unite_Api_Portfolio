class AddSearchCriteriaToEventLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :event_locations, :search_criteria, :text, array: true, default: [], null: false
    add_column :event_locations, :search_venue_types, :text, array: true, default: [], null: false
  end
end
