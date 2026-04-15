class AddDurationMinutesToWorkShifts < ActiveRecord::Migration[8.1]
  def change
    add_column :work_shifts, :duration_minutes, :integer
  end
end
