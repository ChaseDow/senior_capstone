class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.string :title
      t.date :starts_at
      t.date :ends_at
      t.string :meeting_days
      t.time :
      t.string :professor
      t.string :location
      t.text :description

      t.timestamps
    end
  end
end
