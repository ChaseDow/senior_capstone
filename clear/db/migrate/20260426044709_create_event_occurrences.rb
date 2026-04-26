class CreateEventOccurrences < ActiveRecord::Migration[8.1]
  def change
    create_table :event_occurrences do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user,  null: false, foreign_key: true
      t.date    :occurs_on,     null: false
      t.boolean :completed,     null: false, default: false
      t.datetime :completed_at
      t.decimal :duration_hours, precision: 4, scale: 2

      t.timestamps
    end

    add_index :event_occurrences, [:user_id, :event_id, :occurs_on],
              unique: true,
              name: "index_event_occurrences_unique"
  end
end
