class AddTrackableToEventsCoursesWorkShifts < ActiveRecord::Migration[8.1]
  def change
    add_column :events,      :trackable, :boolean, default: false, null: false
    add_column :courses,     :trackable, :boolean, default: false, null: false
    add_column :work_shifts, :trackable, :boolean, default: false, null: false
  end
end
