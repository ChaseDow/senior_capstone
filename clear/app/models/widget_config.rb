class WidgetConfig < ApplicationRecord
  belongs_to :user

  WIDGET_DEFAULTS = {
    "stat"     => { w: 2, h: 2 },
    "progress" => { w: 3, h: 2 },
    "line"     => { w: 4, h: 3 },
    "bar"      => { w: 4, h: 3 },
    "pie"      => { w: 3, h: 3 },
    "area"     => { w: 4, h: 3 },
    "heatmap"  => { w: 6, h: 3 },
  }.freeze

  CONFIGURED_TYPES = %w[stat progress].freeze
  SOURCE_CLASSES   = { "Event" => "Event", "Course" => "Course", "WorkShift" => "WorkShift" }.freeze
  DATE_COLUMNS     = { "Event" => :starts_at, "Course" => :start_date, "WorkShift" => :start_date }.freeze

  # ── Display ────────────────────────────────────────────────────────────────

  def display_title
    return title if title.present?
    return "#{source_type} #{metric.humanize}" if source_type.present? && metric.present?
    widget_type.humanize
  end

  def effective_w = gs_w || WIDGET_DEFAULTS.dig(widget_type, :w) || 2
  def effective_h = gs_h || WIDGET_DEFAULTS.dig(widget_type, :h) || 2

  # ── Data computation ───────────────────────────────────────────────────────

  # Returns the scalar value for "stat"-style widgets, or nil for mock widgets.
  def compute_value
    return nil unless source_type.present? && metric.present?
    return nil unless SOURCE_CLASSES.key?(source_type)

    klass = source_type.constantize
    scope = source_id.present? ? klass.where(id: source_id) : klass.where(user: user, trackable: true)
    scope = apply_period(scope)

    case metric
    when "count"          then scope.count
    when "duration_hours" then (scope.sum(:duration_minutes).to_f / 60).round(1)
    end
  end

  # Returns {current:, goal:, pct:} for progress widgets.
  def compute_progress
    current = compute_value.to_f
    g       = goal.to_f
    { current: current, goal: g, pct: g.positive? ? [(current / g * 100).round, 100].min : 0 }
  end

  # Full JSON payload sent to the front-end.
  def as_widget_json
    base = {
      id:          id,
      type:        widget_type,
      title:       display_title,
      x:           gs_x,
      y:           gs_y,
      w:           effective_w,
      h:           effective_h,
      source_type: source_type,
      source_id:   source_id,
      metric:      metric,
      period:      period,
      goal:        goal&.to_f,
    }

    case widget_type
    when "stat"     then base.merge(value: compute_value)
    when "progress" then base.merge(compute_progress)
    else                 base
    end
  end

  private

  def apply_period(scope)
    return scope if period.blank? || period == "all_time"

    date_col = DATE_COLUMNS[source_type]
    return scope unless date_col

    range = case period
            when "week"  then Date.current.beginning_of_week..Date.current.end_of_week
            when "month" then Date.current.beginning_of_month..Date.current.end_of_month
            end
    range ? scope.where(date_col => range) : scope
  end
end
