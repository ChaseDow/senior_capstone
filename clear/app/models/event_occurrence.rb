class EventOccurrence < ApplicationRecord
  belongs_to :event
  belongs_to :user

  scope :completed, -> { where(completed: true) }
  scope :past,      -> { where("occurs_on <= ?", Date.current) }
  scope :for_event, ->(event_id) { where(event_id: event_id) }

  def mark_complete!
    update!(completed: true, completed_at: Time.current)
  end

  def mark_incomplete!
    update!(completed: false, completed_at: nil)
  end
end
