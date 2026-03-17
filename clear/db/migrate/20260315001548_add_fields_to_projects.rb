class AddFieldsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :title, :string, null: false
    add_column :projects, :description, :text
    add_column :projects, :user_id, :bigint, null: false
  end
end
