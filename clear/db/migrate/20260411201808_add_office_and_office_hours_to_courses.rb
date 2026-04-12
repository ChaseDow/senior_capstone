class AddOfficeAndOfficeHoursToCourses < ActiveRecord::Migration[8.0]
  def change
    add_column :courses, :office, :string
    add_column :courses, :office_hours, :text
  end
end
