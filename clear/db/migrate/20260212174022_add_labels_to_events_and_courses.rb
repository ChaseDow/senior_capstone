# Frozen_string_literal:true

class AddLabelsToEventsAndCourses < ActiveRecord::Migration[8.1]
  def change
    add_reference :events, :label, foreign_key: true
    add_reference :courses, :label, foreign_key: true
  end
end
