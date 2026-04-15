class AddUsernameToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :username, :string
    execute <<~SQL
      UPDATE users
      SET username = split_part(email, '@', 1)
      WHERE username IS NULL AND email IS NOT NULL;
    SQL
    change_column_null :users, :username, false
    add_index :users, :username
  end

  def down
    remove_index :users, :username if index_exists?(:users, :username)
    remove_column :users, :username
  end
end
