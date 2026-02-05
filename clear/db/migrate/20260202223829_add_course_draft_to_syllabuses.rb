class AddCourseDraftToSyllabuses < ActiveRecord::Migration[8.1]
  def change
    add_column :syllabuses, :course_draft, :jsonb unless column_exists?(:syllabuses, :course_draft)
  end
end
