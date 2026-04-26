# frozen_string_literal: true

class Event < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true
  has_many :event_exceptions,  dependent: :destroy
  has_many :event_occurrences, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  validates :title, presence: true
  validates :starts_at, presence: true
  validate :ends_at_after_starts_at, if: -> { starts_at.present? && ends_at.present? }

  validates :color,
            format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a hex color like #34D399" },
            allow_nil: true

  validates :repeat_until, presence: true, if: :recurring?
  validate :repeat_days_present_if_recurring
  validate :repeat_days_are_valid_weekdays
  validate :repeat_until_not_before_start, if: -> { recurring? && repeat_until.present? && starts_at.present? }

  before_validation :derive_ends_at_from_duration
  before_validation :normalize_recurrence_fields
  before_validation :normalize_color

  after_create_commit :create_notification

  Occurrence = Struct.new(:event, :starts_at, :ends_at, :draft_status, keyword_init: true) do
    delegate :id, :title, :location, :description, :color, :contrast_text_color, to: :event
  end

  def occurrences_between(range_start, range_end)
    unless recurring?
      return [ Occurrence.new(event: self, starts_at: starts_at, ends_at: ends_at) ]
    end

    window_start_date = [ range_start.to_date, starts_at.to_date ].max
    window_end_date   = [ range_end.to_date, repeat_until ].min
    return [] if window_end_date < window_start_date

    start_time = starts_at.in_time_zone
    duration = ends_at.present? ? (ends_at.in_time_zone - start_time) : nil
    excluded = event_exceptions.where(excluded_date: window_start_date..window_end_date)
                               .pluck(:excluded_date).to_set

    out = []
    d = window_start_date
    while d <= window_end_date
      if repeat_days.include?(d.wday) && !excluded.include?(d)
        occ_start = Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min, start_time.sec)
        occ_end   = duration.present? ? (occ_start + duration) : nil
        out << Occurrence.new(event: self, starts_at: occ_start, ends_at: occ_end)
      end
      d += 1.day
    end

    out
  end

  def contrast_text_color
    hex = color.to_s.delete("#")
    return "#0A0A0A" unless hex.length == 6

    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    luminance = (0.2126 * srgb_linear(r) + 0.7152 * srgb_linear(g) + 0.0722 * srgb_linear(b))

    luminance > 0.55 ? "#0A0A0A" : "#F9FAFB"
  end

  # Resolve the event's per-session duration in minutes.
  # Preference order: explicit duration_minutes > computed from ends_at - starts_at > 60 fallback.
  # The computed branch matters because many events in this app have ends_at set
  # but no duration_minutes (e.g. events created before duration_minutes was a column).
  def effective_duration_minutes
    return duration_minutes if duration_minutes.present?
    return ((ends_at - starts_at) / 60.0).round if starts_at.present? && ends_at.present?
    60
  end

  # Generate one EventOccurrence per past date this event has occurred on.
  # Uses the same recurrence logic as occurrences_between so the two stay in sync.
  # Self-heals duration_hours on existing occurrences so a corrected event
  # duration propagates the next time the user opens the widget.
  def generate_past_occurrences_for(user)
    duration_hrs = effective_duration_minutes.to_f / 60.0
    today        = Date.current

    upsert = lambda do |date|
      occ = EventOccurrence.find_or_create_by!(event: self, user: user, occurs_on: date) do |o|
        o.duration_hours = duration_hrs
      end
      occ.update!(duration_hours: duration_hrs) if occ.duration_hours.to_f != duration_hrs
    end

    if recurring? && repeat_days.present?
      start  = starts_at.to_date
      finish = [ repeat_until || today, today ].min
      excluded = event_exceptions.pluck(:excluded_date).to_set

      date = start
      while date <= finish
        upsert.call(date) if repeat_days.include?(date.wday) && !excluded.include?(date)
        date += 1.day
      end
    else
      return unless starts_at.present? && starts_at.to_date <= today
      upsert.call(starts_at.to_date)
    end
  end

  private

  def derive_ends_at_from_duration
    return if ends_at.present? || starts_at.blank? || duration_minutes.blank?
    self.ends_at = starts_at + duration_minutes.minutes
  end

  def ends_at_after_starts_at
    return if ends_at >= starts_at
    errors.add(:ends_at, "must be after the start time")
  end

  def normalize_recurrence_fields
    self.repeat_days = Array(repeat_days).reject(&:blank?).map(&:to_i).uniq.sort

    unless recurring?
      self.repeat_days = []
      self.repeat_until = nil
    end
  end

  def normalize_color
    self.color = color.to_s.strip.upcase
    self.color = "#34D399" if color.blank?
  end

  def repeat_days_present_if_recurring
    return unless recurring?
    errors.add(:repeat_days, "pick at least one day") if repeat_days.blank?
  end

  def repeat_days_are_valid_weekdays
    return if repeat_days.blank?
    invalid = repeat_days.reject { |d| d.is_a?(Integer) && d.between?(0, 6) }
    errors.add(:repeat_days, "contains invalid weekday values") if invalid.any?
  end

  def repeat_until_not_before_start
    return if repeat_until >= starts_at.to_date
    errors.add(:repeat_until, "must be on/after the start date")
  end

  def create_notification
    Notification.create!(
      user: user,
      notifiable: self,
      category: (priority.present? && priority > 0) ? "high_priority" : "event_created",
      message: starts_at ? "#{title} at #{starts_at.strftime("%-b %-d at %-I:%M %p")}" : title
    )
  end

  def srgb_linear(channel_0_255)
    c = channel_0_255 / 255.0
    c <= 0.03928 ? (c / 12.92) : (((c + 0.055) / 1.055)**2.4)
  end

  def self.ransackable_attributes(auth_object = nil)
    [ "all_day", "color", "created_at", "description", "duration_minutes", "ends_at", "location", "recurring", "repeat_days", "repeat_until", "starts_at", "title", "updated_at" ]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
