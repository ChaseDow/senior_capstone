# Frozen_string_literal:true

class AddUserToEvents < ActiveRecord::Migration[8.1]
  def up
    add_reference :events, :user, null: true, foreign_key: true

    user_id = select_value("SELECT id FROM users ORDER BY created_at ASC LIMIT 1")
    raise "No users exist to backfill events.user_id" unless user_id

    execute <<~SQL
      UPDATE events
      SET user_id = #{user_id}
      WHERE user_id IS NULL
    SQL

    change_column_null :events, :user_id, false
    add_index :events, :user_id unless index_exists?(:events, :user_id)
  end

  def down
    remove_reference :events, :user, foreign_key: true
  end
end
