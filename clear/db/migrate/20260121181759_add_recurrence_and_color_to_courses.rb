# frozen_string_literal: true

class AddRecurrenceAndColorToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :recurring, :boolean, null: false, default: false
    add_column :courses, :repeat_days, :integer, array: true, null: false, default: []
    add_column :courses, :repeat_until, :date
    add_column :courses, :color, :string, null: false, default: "#34D399"

    add_index :courses, %i[user_id start_date]
    add_index :courses, %i[user_id repeat_until]
  end
end
