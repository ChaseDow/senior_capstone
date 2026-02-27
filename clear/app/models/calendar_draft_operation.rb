# frozen_string_literal: true

class CalendarDraftOperation < ApplicationRecord
  belongs_to :calendar_draft

  # Avoid enum value names like "create" because they collide with ActiveRecord and other enums.
  enum :op_type, { add: 0, change: 1, remove: 2 }
  enum :status,  { pending: 0, accepted: 1, rejected: 2, conflict: 3 }

  validates :target_type, presence: true
  validates :payload, presence: true
end
