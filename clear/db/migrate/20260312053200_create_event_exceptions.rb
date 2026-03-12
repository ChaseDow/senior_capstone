class CreateEventExceptions < ActiveRecord::Migration[8.1]
  def change
    create_table :event_exceptions do |t|
      t.references :event, null: false, foreign_key: true
      t.date :excluded_date, null: false

      t.timestamps
    end

    add_index :event_exceptions, [ :event_id, :excluded_date ], unique: true
  end
end
