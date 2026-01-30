class CreateSyllabuses < ActiveRecord::Migration[8.1]
  def change
    create_table :syllabuses do |t|
      t.string   :title, null: false
      t.datetime :created_at, null: false
    end
  end
end
