class ConfirmExistingUsers < ActiveRecord::Migration[8.1]
  def up
    User.where(confirmed_at: nil).update_all(confirmed_at: Time.current)
  end

  def down
    # irreversible - cannot know which users were confirmed by this migration
  end
end
