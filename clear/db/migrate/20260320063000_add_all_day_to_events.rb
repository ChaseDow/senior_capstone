class AddAllDayToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :all_day, :boolean, default: false, null: false
  end
end
