# frozen_string_literal: true

class AddRecurrenceAndColorToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :recurring, :boolean, null: false, default: false
    add_column :events, :repeat_days, :integer, array: true, null: false, default: []
    add_column :events, :repeat_until, :date
    add_column :events, :color, :string, null: false, default: "#34D399"

    add_index :events, %i[user_id starts_at]
    add_index :events, %i[user_id repeat_until]
  end
end
