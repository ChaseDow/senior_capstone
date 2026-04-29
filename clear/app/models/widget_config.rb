# frozen_string_literal: true

class WidgetConfig < ApplicationRecord
  belongs_to :user

  WIDGET_TYPES = [
    { key: "bar_chart",    label: "Bar Chart",    description: "Visualize event frequency over time" },
    { key: "line_chart",   label: "Line Chart",   description: "Track trends over a date range" },
    { key: "progress_bar", label: "Progress Bar", description: "Track progress toward a goal" },
    { key: "stat_card",    label: "Stat Card",    description: "Show a single key number" },
    { key: "heatmap",      label: "Heatmap",      description: "See activity patterns by day" }
  ].freeze

  WIDGET_TYPE_KEYS = WIDGET_TYPES.map { |t| t[:key] }.freeze

  DATE_RANGES = {
    "7"  => { label: "Last 7 days",  days: 7 },
    "30" => { label: "Last 30 days", days: 30 },
    "90" => { label: "Last 90 days", days: 90 }
  }.freeze

  validates :widget_type, inclusion: { in: WIDGET_TYPE_KEYS }
  validates :title, presence: true
  validates :grid_x, :grid_y, :grid_w, :grid_h, :grid_min_w, :grid_min_h,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def event_ids
    Array(config["event_ids"]).map(&:to_i)
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

  def stat_metric
    config["stat_metric"].presence || "total_completions"
  end

  def accent_color
    raw = config["color"].to_s
    raw.match?(/\A#[0-9a-fA-F]{6}\z/) ? raw : "#34D399"
  end

  def grid_attrs
    { x: grid_x, y: grid_y, w: grid_w, h: grid_h, min_w: grid_min_w, min_h: grid_min_h }
  end
end
