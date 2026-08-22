class CreateLoginActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :login_activities do |t|
      t.string :scope, comment: "Scope of authentication (e.g., :amigo, :admin)"
      t.string :strategy, comment: "Authentication strategy used (e.g., database, OAuth)"
      t.string :identity, comment: "Identifier used for login (e.g., email or username)"
      t.boolean :success, default: false, null: false, comment: "Indicates whether login was successful"
      t.string :failure_reason, comment: "Reason for login failure (e.g., invalid password)"
      t.references :user, polymorphic: true, comment: "Polymorphic association to the authenticated user (e.g., Amigo)"
      t.string :context, comment: "Context or source of login attempt (e.g., web, API)"
      t.string :ip, comment: "IP address of the login request"
      t.text :user_agent, comment: "User-Agent string from the client"
      t.text :referrer, comment: "Referring page or source of the login request"
      t.string :city, comment: "City from which login originated"
      t.string :region, comment: "Region or state of the login source"
      t.string :country, comment: "Country of the login source"
      t.float :latitude, comment: "Geolocation latitude of login source"
      t.float :longitude, comment: "Geolocation longitude of login source"

      t.datetime :created_at, null: false, comment: "Timestamp when login attempt was recorded"
      t.datetime :updated_at, null: false, comment: "Timestamp when the record was last updated"
    end

    add_index :login_activities, :identity
    add_index :login_activities, :ip
  end
end
