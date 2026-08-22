
# db/migrate/2025xxxxxx_add_details_to_event_locations.rb
class AddDetailsToEventLocations < ActiveRecord::Migration[7.1]
  def change
    change_table :event_locations, bulk: true do |t|
      t.string  :location_type, limit: 32, comment: "Type of venue (cafe, house, etc.)"
      t.string  :owner_name,   limit: 128, comment: "Owner or primary contact for the venue"
      t.integer :capacity_seated,          comment: "Approximate seated capacity"

      t.string  :availability_notes, limit: 256, comment: "Human-readable availability description"

      t.boolean :has_food,       default: false, null: false
      t.boolean :has_drink,      default: false, null: false
      t.boolean :has_internet,   default: false, null: false
      t.boolean :has_big_screen, default: false, null: false
    end
  end
end

