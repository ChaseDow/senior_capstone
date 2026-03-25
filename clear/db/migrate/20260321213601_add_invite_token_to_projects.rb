class AddInviteTokenToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :invite_token, :string
  end
end
