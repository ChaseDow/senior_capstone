class CreateWidgetConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :widget_configs do |t|
      t.references :user,        null: false, foreign_key: true
      t.string     :widget_type, null: false
      t.string     :title
      t.string     :source_type   # "Event" | "Course" | "WorkShift" — nil for mock/visual widgets
      t.string     :metric        # "count" | "duration_hours"
      t.string     :period        # "week" | "month" | "all_time"
      t.decimal    :goal,         precision: 10, scale: 2
      t.integer    :gs_x
      t.integer    :gs_y
      t.integer    :gs_w
      t.integer    :gs_h
      t.timestamps
    end
  end
end
