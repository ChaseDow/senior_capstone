class CreateWidgetConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :widget_configs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :widget_type, null: false
      t.string :title, null: false
      t.integer :grid_x, default: 0, null: false
      t.integer :grid_y, default: 0, null: false
      t.integer :grid_w, default: 4, null: false
      t.integer :grid_h, default: 3, null: false
      t.integer :grid_min_w, default: 2, null: false
      t.integer :grid_min_h, default: 2, null: false
      t.jsonb :config, default: {}, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :widget_configs, [ :user_id, :position ]
  end
end
