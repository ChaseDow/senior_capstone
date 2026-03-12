# frozen_string_literal: true

class EventException < ApplicationRecord
  belongs_to :event

  validates :excluded_date, presence: true,
                            uniqueness: { scope: :event_id }
end
