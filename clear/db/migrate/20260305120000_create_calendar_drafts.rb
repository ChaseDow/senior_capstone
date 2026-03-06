class CreateCalendarDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_drafts do |t|
      t.bigint :user_id, null: false
      t.jsonb :operations, null: false, default: []
      t.jsonb :previous_operations, null: false, default: []
      t.timestamps
    end

    add_index :calendar_drafts, :user_id, unique: true
    add_foreign_key :calendar_drafts, :users
  end
end
