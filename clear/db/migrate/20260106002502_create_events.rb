# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :location
      t.text :description

      t.timestamps
    end
  end
end
