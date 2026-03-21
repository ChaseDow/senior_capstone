class WorkShift < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :color, presence: true

  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  scope :active, -> {
    where("repeat_until IS NULL OR repeat_until >= ?", Date.current)
  }

  scope :ordered, -> { order(:start_time) }

  DAY_NAMES = { 0 => "Sun", 1 => "Mon", 2 => "Tue", 3 => "Wed",
                4 => "Thu", 5 => "Fri", 6 => "Sat" }.freeze

  Occurrence = Struct.new(:event, :starts_at, :ends_at, :draft_status, keyword_init: true) do
    delegate :id, :title, :location, :description, :color, :contrast_text_color, to: :event
  end

  def occurrences_between(range_start, range_end)
    window_start_date = range_start.to_date
    window_end_date   = range_end.to_date
    window_end_date   = [ window_end_date, repeat_until ].min if repeat_until.present?
    return [] if window_end_date < window_start_date

    days_set = Array(repeat_days).map(&:to_i)
    out = []
    d = window_start_date
    while d <= window_end_date
      if days_set.include?(d.wday)
        occ_start = Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min)
        occ_end   = Time.zone.local(d.year, d.month, d.day, end_time.hour, end_time.min)
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

  def repeat_days_labels
    Array(repeat_days).sort.filter_map { |d| DAY_NAMES[d.to_i] }.join(" | ")
  end

  def formatted_time_range
    return nil unless start_time.present? && end_time.present?
    "#{start_time.strftime('%-I:%M%P')} - #{end_time.strftime('%-I:%M%P')}"
  end

  def end_time_after_start_time
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end

  private

  def srgb_linear(channel_0_255)
    c = channel_0_255 / 255.0
    c <= 0.03928 ? (c / 12.92) : (((c + 0.055) / 1.055)**2.4)
  end
end
