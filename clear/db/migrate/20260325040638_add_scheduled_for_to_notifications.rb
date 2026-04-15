class AddScheduledForToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :scheduled_for, :datetime

    # Prevents duplicate reminders for the same item + time
    add_index :notifications,
              [ :notifiable_type, :notifiable_id, :category, :scheduled_for ],
              unique: true,
              where: "scheduled_for IS NOT NULL",
              name: "idx_notifications_reminder_dedup"
  end
end
