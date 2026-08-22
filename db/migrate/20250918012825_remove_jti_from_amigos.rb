# db/migrate/20250918005500_remove_jti_from_amigos.rb
class RemoveJtiFromAmigos < ActiveRecord::Migration[7.1]
  def up
    remove_column :amigos, :jti if column_exists?(:amigos, :jti)
  end

  def down
    add_column :amigos, :jti, :string, null: true unless column_exists?(:amigos, :jti)
    add_index  :amigos, :jti, unique: true
  end
end
