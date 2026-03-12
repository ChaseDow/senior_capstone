class AddDurationMinutesToEventsAndCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :duration_minutes, :integer
    add_column :courses, :duration_minutes, :integer
  end
end
