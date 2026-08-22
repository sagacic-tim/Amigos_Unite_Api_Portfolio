 class AddRoleToAmigos < ActiveRecord::Migration[7.1]
   def change
     add_column :amigos, :role, :integer, null: false, default: 0
     add_index  :amigos, :role
   end
 end
