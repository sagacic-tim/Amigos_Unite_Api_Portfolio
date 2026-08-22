class AvatarSourceToAmigos < ActiveRecord::Migration[7.1]
  def change
    add_column :amigos, :avatar_source, :string,  comment: "upload|gravatar|url|default"
    add_column :amigos, :avatar_remote_url, :string, comment: "When avatar_source = url"
    add_column :amigos, :avatar_synced_at, :datetime
  end
end
