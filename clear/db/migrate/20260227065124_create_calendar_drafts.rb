# frozen_stirng_literal:true
class CreateCalendarDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_drafts do |t|
      t.references :user, null: false, foreign_key: true

      t.string  :title, null: false, default: "Draft"
      t.integer :status, null: false, default: 0 # open/applied/discarded

      t.jsonb :context, null: false, default: {}

      t.bigint :base_calendar_version
      t.datetime :applied_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :calendar_drafts, [ :user_id, :status ]
    add_index :calendar_drafts, :created_at
  end
end
