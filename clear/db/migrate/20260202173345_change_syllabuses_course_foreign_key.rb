class ChangeSyllabusesCourseForeignKey < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :syllabuses, :courses
    add_foreign_key :syllabuses, :courses, on_delete: :nullify
  end
end
