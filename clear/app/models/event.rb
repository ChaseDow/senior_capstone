# frozen_string_literal: true

class Event < ApplicationRecord
  belongs_to :user
  validates :title, presence: true
  validates :starts_at, presence: true
  validate :ends_at_after_starts_at, if: -> { starts_at.present? && ends_at.present? }

  private

  def ends_at_after_starts_at
    return if ends_at >= starts_at

    errors.add(:ends_at, "must be after the start time")
  end
end
