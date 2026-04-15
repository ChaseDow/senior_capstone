class RemoveStartDateFromProjects < ActiveRecord::Migration[8.1]
  def change
    remove_column :projects, :start_date, :date
  end
end
