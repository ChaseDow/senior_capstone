class RemoveUpdatedFromSyllabuses < ActiveRecord::Migration[8.1]
  def change
    remove_column :syllabuses, :updated_at, :datetime
  end
end
