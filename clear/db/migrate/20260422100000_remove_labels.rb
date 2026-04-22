class RemoveLabels < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :courses, :labels, if_exists: true
    remove_foreign_key :events,  :labels, if_exists: true
    remove_column :courses, :label_id, if_exists: true
    remove_column :events,  :label_id, if_exists: true
    drop_table :labels, if_exists: true
  end

  def down
    create_table :labels do |t|
      t.string  :name,  null: false
      t.string  :color, null: false, default: "#78866B"
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :labels, [:user_id, :name], unique: true
    add_reference :courses, :label, foreign_key: true
    add_reference :events,  :label, foreign_key: true
  end
end
