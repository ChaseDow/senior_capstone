class AddPriorityToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :priority, :integer, null: true
  end
end
