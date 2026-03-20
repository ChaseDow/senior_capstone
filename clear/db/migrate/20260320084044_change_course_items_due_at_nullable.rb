class ChangeCourseItemsDueAtNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :course_items, :due_at, true
  end
end
