class CreateProjectInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :project_invitations do |t|
      t.references :project, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.string :email
      t.string :token
      t.datetime :accepted_at

      t.timestamps
    end
    add_index :project_invitations, :token, unique: true
  end
end
