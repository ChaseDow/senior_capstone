class ChangeUserIdNullableInProjects < ActiveRecord::Migration[8.1]
  def change
    change_column_null :projects, :user_id, true
  end
end
