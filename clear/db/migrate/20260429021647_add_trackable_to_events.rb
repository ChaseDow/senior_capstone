class AddTrackableToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :trackable, :boolean, default: false, null: false
    add_index :events, [ :user_id, :trackable ]
  end
end
