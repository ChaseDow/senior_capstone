class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.string :title
      t.string :term
      t.time :start_time
      t.time :end_time
      t.date :start_date
      t.date :end_date
      t.string :meeting_days
      t.string :professor
      t.string :location
      t.text :description

      t.timestamps
    end
  end
end
