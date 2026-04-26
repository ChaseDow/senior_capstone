class CreateTrackingEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :tracking_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :trackable_type,  null: false
      t.integer :trackable_id,    null: false
      t.string  :trackable_label, null: false
      t.boolean :completed,       null: false, default: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :tracking_entries,
              [:user_id, :trackable_type, :trackable_id],
              unique: true,
              name: "index_tracking_entries_on_user_and_trackable"
  end
end
