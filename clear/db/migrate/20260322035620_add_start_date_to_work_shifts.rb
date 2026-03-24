class AddStartDateToWorkShifts < ActiveRecord::Migration[8.1]
  def change
    add_column :work_shifts, :start_date, :date
  end
end
