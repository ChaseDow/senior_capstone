class TrackingEntry < ApplicationRecord
  belongs_to :user
  belongs_to :trackable, polymorphic: true

  validates :trackable_type, inclusion: { in: %w[Event Course CourseItem WorkShift] }
  validates :trackable_label, presence: true
  validates :trackable_id, uniqueness: { scope: [:user_id, :trackable_type] }

  def mark_complete!
    update!(completed: true, completed_at: Time.current)
  end

  def mark_incomplete!
    update!(completed: false, completed_at: nil)
  end
end
