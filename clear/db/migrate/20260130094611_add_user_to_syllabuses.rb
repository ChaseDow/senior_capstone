class AddUserToSyllabuses < ActiveRecord::Migration[8.1]
  def change
    add_reference :syllabuses, :user, null: false, foreign_key: true
  end
end
