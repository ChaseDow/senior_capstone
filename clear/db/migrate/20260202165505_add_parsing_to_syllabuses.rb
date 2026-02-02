class AddParsingToSyllabuses < ActiveRecord::Migration[8.1]
  def change
    add_column :syllabuses, :parse_status, :string
    add_column :syllabuses, :parse_error, :text
    add_column :syllabuses, :parsed_text, :text
    add_column :syllabuses, :parsed_at, :datetime
    add_reference :syllabuses, :course, foreign_key: true
    # (or explicitly: null: true)
  end
end
