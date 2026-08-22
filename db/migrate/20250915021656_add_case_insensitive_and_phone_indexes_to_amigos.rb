# db/migrate/20250915021656_add_case_insensitive_and_phone_indexes_to_amigos.rb
class AddCaseInsensitiveAndPhoneIndexesToAmigos < ActiveRecord::Migration[7.1]
  # required when using :concurrently
  disable_ddl_transaction!

  def up
    # Case-insensitive UNIQUE indexes (functional)
    add_index :amigos, "LOWER(user_name)",
              unique: true,
              name: "idx_amigos_user_name_ci",
              algorithm: :concurrently unless index_name_exists?(:amigos, "idx_amigos_user_name_ci")

    add_index :amigos, "LOWER(email)",
              unique: true,
              name: "idx_amigos_email_ci",
              algorithm: :concurrently unless index_name_exists?(:amigos, "idx_amigos_email_ci")

    # Phones: unique only when present (partial indexes)
    add_index :amigos, :phone_1,
              unique: true,
              where: "phone_1 IS NOT NULL",
              name: "idx_amigos_phone_1_not_null",
              algorithm: :concurrently unless index_name_exists?(:amigos, "idx_amigos_phone_1_not_null")

    add_index :amigos, :phone_2,
              unique: true,
              where: "phone_2 IS NOT NULL",
              name: "idx_amigos_phone_2_not_null",
              algorithm: :concurrently unless index_name_exists?(:amigos, "idx_amigos_phone_2_not_null")
  end

  def down
    remove_index :amigos, name: "idx_amigos_user_name_ci"       if index_name_exists?(:amigos, "idx_amigos_user_name_ci")
    remove_index :amigos, name: "idx_amigos_email_ci"           if index_name_exists?(:amigos, "idx_amigos_email_ci")
    remove_index :amigos, name: "idx_amigos_phone_1_not_null"   if index_name_exists?(:amigos, "idx_amigos_phone_1_not_null")
    remove_index :amigos, name: "idx_amigos_phone_2_not_null"   if index_name_exists?(:amigos, "idx_amigos_phone_2_not_null")
  end
end
