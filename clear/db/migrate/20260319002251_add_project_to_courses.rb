class AddProjectToCourses < ActiveRecord::Migration[8.1]
  def change
    add_reference :courses, :project, null: true, foreign_key: true
  end
end
