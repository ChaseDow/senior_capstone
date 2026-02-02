class AddCodeAndTermToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :code, :string unless column_exists?(:courses, :code)
  end
end
