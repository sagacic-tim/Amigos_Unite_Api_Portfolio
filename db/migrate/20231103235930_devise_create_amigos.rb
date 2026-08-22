class DeviseCreateAmigos < ActiveRecord::Migration[7.1]
  def change
    create_table :amigos do |t|
      ## Database authenticatable
      t.string :first_name, limit: 50, comment: "First name of the Amigo"
      t.string :last_name, limit: 50, comment: "Last name of the Amigo"
      t.string :user_name, null: false, default: "", limit: 50, comment: "Unique username"
      t.string :email, null: false, default: "", limit: 50, comment: "Primary email address"
      t.string :secondary_email, default: "", limit: 50, comment: "Secondary email address"
      t.string :phone_1, limit: 35, comment: "Primary phone number"
      t.string :phone_2, limit: 35, comment: "Secondary phone number"
      t.string :encrypted_password, null: false, default: "", comment: "Devise-encrypted password"

      ## Add JTI - JSON Web Token Identifier
      t.string :jti, null: false, comment: "JWT unique identifier for token revocation"

      ## Recoverable
      t.string   :reset_password_token, comment: "Token for resetting password"
      t.datetime :reset_password_sent_at, comment: "Timestamp when password reset token was sent"

      ## Rememberable
      t.datetime :remember_created_at, comment: "Timestamp for remember-me feature"

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false, comment: "Total sign-in count"
      t.datetime :current_sign_in_at, comment: "Timestamp of current sign-in"
      t.datetime :last_sign_in_at, comment: "Timestamp of last sign-in"
      t.string   :current_sign_in_ip, comment: "IP address of current sign-in"
      t.string   :last_sign_in_ip, comment: "IP address of last sign-in"

      ## Confirmable
      t.string   :confirmation_token, comment: "Token used for email confirmation"
      t.datetime :confirmed_at, comment: "Timestamp when email was confirmed"
      t.datetime :confirmation_sent_at, comment: "Timestamp when confirmation instructions were sent"
      t.string   :unconfirmed_email, comment: "Email address waiting for confirmation"

      ## Lockable
      t.integer  :failed_attempts, default: 0, null: false, comment: "Number of failed login attempts"
      t.string   :unlock_token, comment: "Token for unlocking account"
      t.datetime :locked_at, comment: "Timestamp when account was locked"

      t.timestamps null: false
    end

    add_index :amigos, :user_name,            unique: true
    add_index :amigos, :email,                unique: true
    add_index :amigos, :reset_password_token, unique: true
    add_index :amigos, :confirmation_token,   unique: true
    add_index :amigos, :unlock_token,         unique: true
    add_index :amigos, :jti,                  unique: true
    add_index :amigos, :phone_1, unique: true, where: "phone_1 IS NOT NULL"
    add_index :amigos, :phone_2, unique: true, where: "phone_2 IS NOT NULL"
  end
end
