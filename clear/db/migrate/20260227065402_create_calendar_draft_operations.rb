class CreateCalendarDraftOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_draft_operations do |t|
      t.references :calendar_draft, null: false, foreign_key: true

      t.integer :op_type, null: false
      t.string  :target_type, null: false
      t.bigint  :target_id

      t.integer :status, null: false, default: 0
      t.integer :position, null: false, default: 0

      t.jsonb :payload, null: false, default: {}
      t.jsonb :ai_metadata, null: false, default: {}

      t.timestamps
    end

    add_index :calendar_draft_operations, [ :calendar_draft_id, :position ], name: "idx_draft_ops_order"
    add_index :calendar_draft_operations, [ :target_type, :target_id ], name: "idx_draft_ops_target"
    add_index :calendar_draft_operations, :status
  end
end
