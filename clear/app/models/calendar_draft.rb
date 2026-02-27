class CalendarDraft < ApplicationRecord
  belongs_to :user
  has_many :operations, class_name: "CalendarDraftOperation", dependent: :destroy

  enum :status, { open: 0, applied: 1, discarded: 2 }

  validates :title, presence: true
end
