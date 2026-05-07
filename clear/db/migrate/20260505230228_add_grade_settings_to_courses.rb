class AddGradeSettingsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :grade_calculation, :string, default: "points", null: false
    add_column :courses, :grading_scale_preset, :string, default: "ten_point", null: false
  end
end
