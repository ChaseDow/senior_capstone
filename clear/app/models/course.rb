# frozen_string_literal: true

class Course < ApplicationRecord
  validates :title, presence: true
  validates :starts_at, presence: true
  validates :meeting_days, presence: true
  validate :valid_meeting_days, if: -> { meeting_days.present? }
  validate :ends_at_after_starts_at, if: -> { starts_at.present? && ends_at.present? }

  private

  def ends_at_after_starts_at
    return if ends_at >= starts_at

    errors.add(:ends_at, "must be after the start time")
  end

  def valid_meeting_days
    valid_days = %w[M T W R F S U]
    days = meeting_days.upcase.chars
    invalid_days = days - valid_days

    return if invalid_days.empty?

    errors.add(:meeting_days, "contains invalid day(s): #{invalid_days.join(', ')}. Use M T W R F (example: MWF or TR)")
  end
end
