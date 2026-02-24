# Frozen_string_literal:true


class AddCourseItemtoCourse < ActiveRecord::Migration[8.1]
  def change
    create_table :course_items do |t|
      t.references :course, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :kind, null: false, default: 0
      t.datetime :due_at, null: false
      t.text :details

      t.timestamps
    end

    add_index :course_items, [ :course_id, :due_at ]
  end
end
