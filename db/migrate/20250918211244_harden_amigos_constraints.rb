# db/migrate/20250918211244_harden_amigos_constraints.rb
class HardenAmigosConstraints < ActiveRecord::Migration[7.1]
  def up
    # --- Helpers -------------------------------------------------------------
    def drop_all_indexes_on(table, column)
      connection.indexes(table).each do |idx|
        next unless idx.columns == [column.to_s]
        remove_index table, name: idx.name, if_exists: true
      end
    end

    # --- jti (remove if you no longer use it) --------------------------------
    if column_exists?(:amigos, :jti)
      remove_index  :amigos, :jti, if_exists: true
      remove_column :amigos, :jti
    end

    # --- Clear string defaults -----------------------------------------------
    change_column_default :amigos, :email,           nil
    change_column_default :amigos, :user_name,       nil
    change_column_default :amigos, :secondary_email, nil

    # --- Email / Username: case-insensitive unique ---------------------------
    remove_index :amigos, name: "index_amigos_on_email",     if_exists: true
    remove_index :amigos, name: "index_amigos_on_user_name", if_exists: true

    add_index :amigos, "LOWER(email)",     unique: true, name: "idx_amigos_email_ci"     unless index_name_exists?(:amigos, "idx_amigos_email_ci")
    add_index :amigos, "LOWER(user_name)", unique: true, name: "idx_amigos_user_name_ci" unless index_name_exists?(:amigos, "idx_amigos_user_name_ci")

    # Optional: secondary_email (unique when present & non-empty)
    add_index :amigos, "LOWER(secondary_email)",
              unique: true,
              where:  "secondary_email IS NOT NULL AND secondary_email <> ''",
              name:   "idx_amigos_secondary_email_ci"                                   unless index_name_exists?(:amigos, "idx_amigos_secondary_email_ci")

    # --- Phones: unique only when present / non-empty -------------------------
    # Some databases will have multiple indexes already; remove them all by name.
    drop_all_indexes_on(:amigos, :phone_1)
    add_index :amigos, :phone_1,
              unique: true,
              where:  "phone_1 IS NOT NULL AND phone_1 <> ''",
              name:   "idx_amigos_phone_1_unique"                                      unless index_name_exists?(:amigos, "idx_amigos_phone_1_unique")

    drop_all_indexes_on(:amigos, :phone_2)
    add_index :amigos, :phone_2,
              unique: true,
              where:  "phone_2 IS NOT NULL AND phone_2 <> ''",
              name:   "idx_amigos_phone_2_unique"                                      unless index_name_exists?(:amigos, "idx_amigos_phone_2_unique")

    # --- Devise token indexes: allow many NULLs via partial uniques -----------
    if index_name_exists?(:amigos, "index_amigos_on_reset_password_token")
      remove_index :amigos, name: "index_amigos_on_reset_password_token"
    end
    add_index :amigos, :reset_password_token,
              unique: true,
              where:  "reset_password_token IS NOT NULL",
              name:   "index_amigos_on_reset_password_token"                            unless index_name_exists?(:amigos, "index_amigos_on_reset_password_token")

    if index_name_exists?(:amigos, "index_amigos_on_confirmation_token")
      remove_index :amigos, name: "index_amigos_on_confirmation_token"
    end
    add_index :amigos, :confirmation_token,
              unique: true,
              where:  "confirmation_token IS NOT NULL",
              name:   "index_amigos_on_confirmation_token"                              unless index_name_exists?(:amigos, "index_amigos_on_confirmation_token")

    if index_name_exists?(:amigos, "index_amigos_on_unlock_token")
      remove_index :amigos, name: "index_amigos_on_unlock_token"
    end
    add_index :amigos, :unlock_token,
              unique: true,
              where:  "unlock_token IS NOT NULL",
              name:   "index_amigos_on_unlock_token"                                    unless index_name_exists?(:amigos, "index_amigos_on_unlock_token")
  end

  def down
    # Remove CI/partial/phone indexes
    %w[
      idx_amigos_email_ci
      idx_amigos_user_name_ci
      idx_amigos_secondary_email_ci
      idx_amigos_phone_1_unique
      idx_amigos_phone_2_unique
      index_amigos_on_reset_password_token
      index_amigos_on_confirmation_token
      index_amigos_on_unlock_token
    ].each { |name| remove_index :amigos, name: name, if_exists: true }

    # Restore simple uniques for email & user_name
    add_index :amigos, :email,     unique: true, name: "index_amigos_on_email"          unless index_name_exists?(:amigos, "index_amigos_on_email")
    add_index :amigos, :user_name, unique: true, name: "index_amigos_on_user_name"      unless index_name_exists?(:amigos, "index_amigos_on_user_name")

    # Restore defaults (optional)
    change_column_default :amigos, :email,           ""
    change_column_default :amigos, :user_name,       ""
    change_column_default :amigos, :secondary_email, ""

    # Re-add jti if rolling back
    unless column_exists?(:amigos, :jti)
      add_column :amigos, :jti, :string, null: false
      add_index  :amigos, :jti, unique: true
    end
  end
end
