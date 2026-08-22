class AddDescriptionToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :description, :text, comment: "Detailed description of the event"
  end
end
