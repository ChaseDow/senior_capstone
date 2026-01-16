class CreateSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false, default: "default"
      t.string :timezone, null: false, default: "american/chicago"
      t.integer :week_starts_on, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :schedules, [:user_id, :name], unique: true
  end
end
