class CreateProjectMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :project_messages do |t|
      t.text :body, null: false
      t.references :user, null: false
      t.references :project, null: false

      t.timestamps
    end

    add_foreign_key :project_messages, :users
    add_foreign_key :project_messages, :projects
  end
end
