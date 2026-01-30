# frozen_string_literal: true

class AddUserToCourses < ActiveRecord::Migration[8.1]
  def up
    add_reference :courses, :user, null: true, foreign_key: true

    user_id = select_value("SELECT id FROM users ORDER BY created_at ASC LIMIT 1")
    raise "No users exist to backfill courses.user_id" unless user_id

    execute <<~SQL
      UPDATE courses
      SET user_id = #{user_id}
      WHERE user_id IS NULL
    SQL

    change_column_null :courses, :user_id, false
    add_index :courses, :user_id unless index_exists?(:courses, :user_id)
  end

  def down
    remove_reference :courses, :user, foreign_key: true
  end
end
