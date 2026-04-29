class CreateEventOccurrences < ActiveRecord::Migration[8.1]
  def change
    create_table :event_occurrences do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :occurred_on, null: false
      t.boolean :completed, default: false, null: false
      t.integer :duration_minutes
      t.text :notes
      t.timestamps
    end

    add_index :event_occurrences, [ :event_id, :user_id, :occurred_on ],
              unique: true, name: "index_event_occurrences_on_event_user_date"
    add_index :event_occurrences, [ :user_id, :occurred_on ]
  end
end
