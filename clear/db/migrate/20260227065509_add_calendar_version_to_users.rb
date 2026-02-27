class AddCalendarVersionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :calendar_version, :bigint, null: false, default: 0
    add_index :users, :calendar_version
  end
end
