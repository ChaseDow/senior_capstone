# frozen_string_literal: true

class WidgetConfig < ApplicationRecord
  belongs_to :user

  WIDGET_TYPES = [
    { key: "progress_bar", label: "Progress Bar", description: "Track progress toward a goal" },
    { key: "pie_chart",    label: "Pie Chart",    description: "Compare event totals as slices" }
  ].freeze

  WIDGET_TYPE_KEYS = WIDGET_TYPES.map { |t| t[:key] }.freeze

  DATE_RANGES = {
    "7"  => { label: "Last 7 days",  days: 7 },
    "30" => { label: "Last 30 days", days: 30 },
    "90" => { label: "Last 90 days", days: 90 }
  }.freeze

  DEFAULT_GRID = {
    "progress_bar" => { w: 4, h: 3, min_w: 2, min_h: 2 },
    "pie_chart"    => { w: 4, h: 4, min_w: 3, min_h: 3 }
  }.freeze

  validates :widget_type, inclusion: { in: WIDGET_TYPE_KEYS }
  validates :title, presence: true

  def event_ids
    Array(config["event_ids"]).map(&:to_i).reject(&:zero?)
  end

  def events
    user.events.where(id: event_ids)
  end

  def date_range_days
    raw = config["date_range"].to_s
    DATE_RANGES.dig(raw, :days) || 30
  end

  def goal
    config["goal"].to_i
  end

  def unit
    config["unit"].presence || "completions"
  end

  def accent_color
    raw = config["color"].to_s
    raw.match?(/\A#[0-9a-fA-F]{6}\z/) ? raw : "#34D399"
  end
end
