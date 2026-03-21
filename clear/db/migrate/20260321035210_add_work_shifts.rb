class AddWorkShifts < ActiveRecord::Migration[8.1]
  def change
    create_table :work_shifts do |t|
      t.references :user, null: false, foreign_key: true

      t.string  :title
      t.string  :color,       null: false, default: "#34D399"
      t.text    :description
      t.string  :location
      t.time    :start_time
      t.time    :end_time
      t.boolean :recurring,    null: false, default: true
      t.string  :repeat_days,  array: true, null: false, default: []
      t.date    :repeat_until

      t.timestamps
    end
  end
end
