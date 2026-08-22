# frozen_string_literal: true

class DeviseCreateModels < ActiveRecord::Migration[7.1]
  def change
    create_table :models do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: "", comment: "User's email address (used for authentication)"
      t.string :encrypted_password, null: false, default: "", comment: "Devise-encrypted password hash"

      ## Recoverable
      t.string   :reset_password_token, comment: "Token for resetting password"
      t.datetime :reset_password_sent_at, comment: "Timestamp when reset password token was sent"

      ## Rememberable
      t.datetime :remember_created_at, comment: "Timestamp for remember-me session (likely unused in API-only apps)"

      # The following modules are commented out. They are typically used in browser-based apps with sessions.
      # Since you're using a stateless JWT API with OAuth support, they are not needed and can be removed.
      #
      # ## Trackable
      # t.integer  :sign_in_count, default: 0, null: false, comment: "Total number of sign-ins"
      # t.datetime :current_sign_in_at, comment: "Timestamp of current sign-in"
      # t.datetime :last_sign_in_at, comment: "Timestamp of previous sign-in"
      # t.string   :current_sign_in_ip, comment: "IP address of current sign-in"
      # t.string   :last_sign_in_ip, comment: "IP address of previous sign-in"
      #
      # ## Confirmable
      # t.string   :confirmation_token, comment: "Token for email confirmation"
      # t.datetime :confirmed_at, comment: "Timestamp when email was confirmed"
      # t.datetime :confirmation_sent_at, comment: "Timestamp when confirmation instructions were sent"
      # t.string   :unconfirmed_email, comment: "Pending email if user updates email"
      #
      # ## Lockable
      # t.integer  :failed_attempts, default: 0, null: false, comment: "Number of failed login attempts"
      # t.string   :unlock_token, comment: "Token to unlock account after locking"
      # t.datetime :locked_at, comment: "Timestamp when account was locked"

      t.timestamps null: false
    end

    add_index :models, :email, unique: true
    add_index :models, :reset_password_token, unique: true
    # add_index :models, :confirmation_token, unique: true
    # add_index :models, :unlock_token, unique: true
  end
end
