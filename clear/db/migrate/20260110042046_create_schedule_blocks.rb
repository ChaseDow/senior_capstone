class CreateScheduleBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_blocks do |t|
      t.references :schedule, null: false
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :title, null: false
      t.string :category, null: false, default: "other"
      t.string :location
      t.text :notes
      t.string :color
      t.boolean :locked, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :schedule_blocks, [:schedule_id, :day_of_week]
    add_index :schedule_blocks, [:schedule_id, :day_of_week, :start_time], name: "index_block_on_schedule_day_start"
    add_check_constraint :schedule_blocks, "day_of_week between 0 and 6", name: "check_blocks_day_of_week"
    add_check_constraint :schedule_blocks, "start_time < end_time", name: "check_blocks_start_before_end"
  end
end
