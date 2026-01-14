# frozen_string_literal: true

class Course < ApplicationRecord
  # belongs_to :term (for right now let's ignore this)
  # belongs_to :user
  before_validation :normalize_meeting_days

  validates :title, presence: true
  # validates :term, presence: true
  validate :valid_meeting_days, if: -> { meeting_days.present? }
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  private

  def normalize_meeting_days
    self.meeting_days = meeting_days&.upcase&.gsub(/\s+/, "")
  end

  def end_time_after_start_time
    return if end_time >= start_time

    errors.add(:end_time, "must be after the start time")
  end

  def end_date_after_start_date
    return if end_date >= start_date

    errors.add(:end_date, "must be after the start date")
  end

  def valid_meeting_days
    valid_days = %w[M T W R F S U]
    days = meeting_days.upcase.chars
    invalid_days = days - valid_days

    return if invalid_days.empty?

    errors.add(:meeting_days, "contains invalid day(s): #{invalid_days.join(', ')}. Use M T W R F (example: MWF or TR)")
  end
end
