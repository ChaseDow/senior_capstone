# frozen_string_literal: true

class EventOccurrence < ApplicationRecord
  belongs_to :event
  belongs_to :user

  validates :occurred_on, presence: true
  validates :event_id, uniqueness: { scope: [ :user_id, :occurred_on ] }
end
