class CreateAmigoDetails < ActiveRecord::Migration[7.1]
  def change
    create_table :amigo_details do |t|
      t.date    :date_of_birth, comment: "Date of birth of the Amigo"
      t.boolean :member_in_good_standing, comment: "Indicates whether the Amigo is in good standing"
      t.boolean :available_to_host, comment: "Whether the Amigo is available to host others"
      t.boolean :willing_to_help, comment: "Whether the Amigo is willing to provide general help"
      t.boolean :willing_to_donate, comment: "Whether the Amigo is willing to contribute donations"
      t.text    :personal_bio, comment: "A short personal biography of the Amigo"
      t.references :amigo, null: false, foreign_key: true, comment: "Foreign key reference to the Amigo record"

      t.timestamps
    end
  end
end
