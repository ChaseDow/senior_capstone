class CreateSyllabuses < ActiveRecord::Migration[8.1]
  def change
    create_table :syllabuses do |t|
      t.timestamps
    end
  end
end
