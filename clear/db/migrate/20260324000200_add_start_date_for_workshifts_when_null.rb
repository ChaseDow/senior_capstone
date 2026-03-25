class AddStartDateForWorkshiftsWhenNull < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE work_shifts
      SET start_date = repeat_until - 1
      WHERE start_date IS NULL
        AND repeat_until IS NOT NULL;
    SQL
  end

  def down
    execute <<~SQL
      UPDATE work_shifts
      SET start_date = NULL
      WHERE repeat_until IS NOT NULL
        AND start_date = repeat_until - 1;
    SQL
  end
end
