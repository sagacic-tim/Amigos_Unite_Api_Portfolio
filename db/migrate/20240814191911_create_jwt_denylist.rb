class CreateJwtDenylist < ActiveRecord::Migration[7.1]
  def change
    create_table :jwt_denylist do |t|
      t.string :jti, null: false, comment: "JWT ID (unique identifier for the token)"
      t.datetime :exp, null: false, comment: "Expiration timestamp of the JWT"

      t.timestamps
    end

    add_index :jwt_denylist, :jti, unique: true
  end
end
