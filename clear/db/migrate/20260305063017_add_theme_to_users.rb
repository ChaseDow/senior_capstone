class AddThemeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :theme, :string, default: "green", null: false
  end
end
