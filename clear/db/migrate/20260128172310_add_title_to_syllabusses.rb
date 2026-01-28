class AddTitleToSyllabusses < ActiveRecord::Migration[8.1]
  def change
    add_column :syllabuses, :title, :string, null: false
  end
end
