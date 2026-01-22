# frozen_string_literal: true

class Course < ApplicationRecord
  belongs_to :user

  # A course must have a title
  validates :title, presence: true

  validates :end_date, presence: true

  # Ensure the meeting time window makes sesne
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  # Ensure the course end date is not before the start date
  validate :end_date_after_start_date, if: -> { start_date.present? && end_date.present? }

  # This lets us visually distinguish courses later in the UI or calendar.
  validates :color,
            format: {
              with: /\A#[0-9a-fA-F]{6}\z/,
              message: "must be a hex color like #34D399"
            },
            allow_nil: true

  # Normalize color before validation so blank or lowercase input
  before_validation :normalize_color

  # Courses are inherently recurring
  validate :repeat_days_present

  # Ensure repeat_days only contains valid weekday integers (0–6).
  validate :repeat_days_are_valid_weekdays

  before_validation :normalize_repeat_days
  before_validation :force_recurrence_defaults

  # Used by the dashboard calendar
  Occurrence = Struct.new(:event, :starts_at, :ends_at, keyword_init: true) do
    delegate :id, :title, :location, :description, :color, :contrast_text_color, to: :event
  end
  # Generate course occurrences within the given date range
  def occurrences_between(range_start, range_end)
    return [] if start_date.blank? || end_date.blank? || repeat_days.blank? || start_time.blank?

    window_start = [ range_start.to_date, start_date ].max
    window_end   = [ range_end.to_date, end_date ].min
    return [] if window_end < window_start

    out = []
    d = window_start
    while d <= window_end
      if repeat_days.include?(d.wday)
        occ_start = Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min, start_time.sec)
        occ_end =
          if end_time.present?
            Time.zone.local(d.year, d.month, d.day,
                            end_time.hour, end_time.min, end_time.sec)
          end
        out << Occurrence.new(event: self, starts_at: occ_start, ends_at: occ_end)
      end
      d += 1.day
    end
    out
  end

  # Text color for calendar readability
  def contrast_text_color
    hex = color.to_s.delete("#")
    return "#0A0A0A" unless hex.length == 6

    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    luminance = (0.2126 * srgb_linear(r) + 0.7152 * srgb_linear(g) + 0.0722 * srgb_linear(b))
    luminance > 0.55 ? "#0A0A0A" : "#F9FAFB"
  end

  private

  # Courses are always recurring in our app
  def force_recurrence_defaults
    self.recurring = true
    self.repeat_until = end_date if end_date.present?
  end

  # Converts repeat_days into a clean, predictable format
  def normalize_repeat_days
    self.repeat_days =
      Array(repeat_days)
        .reject(&:blank?)
        .map(&:to_i)
        .uniq
        .sort
  end

  # Ensures the color is uppercase and defaults to the same green used by Events if none is provided.
  def normalize_color
    self.color = color.to_s.strip.upcase
    self.color = "#34D399" if color.blank?
  end

  # Courses must occur on at least one weekday.
  def repeat_days_present
    errors.add(:repeat_days, "pick at least one day") if repeat_days.blank?
  end

  # Valid weekday values
  def repeat_days_are_valid_weekdays
    return if repeat_days.blank?

    invalid =
      repeat_days.reject { |d| d.is_a?(Integer) && d.between?(0, 6) }

    errors.add(:repeat_days, "contains invalid weekday values") if invalid.any?
  end

  def end_time_after_start_time
    return if end_time >= start_time

    errors.add(:end_time, "must be after the start time")
  end

  def end_date_after_start_date
    return if end_date >= start_date

    errors.add(:end_date, "must be after the start date")
  end

  def srgb_linear(channel)
    c = channel / 255.0
    c <= 0.03928 ? (c / 12.92) : (((c + 0.055) / 1.055)**2.4)
  end
end
