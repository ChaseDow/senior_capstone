# frozen_string_literal:true

class CreateLabels < ActiveRecord::Migration[8.1]
  def change
    create_table :labels do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, null: false, default: "#78866B"
      t.timestamps
    end

    add_index :labels, [ :user_id, :name ], unique: true
  end
end
