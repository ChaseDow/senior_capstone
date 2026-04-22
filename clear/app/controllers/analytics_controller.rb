class AnalyticsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  # GET /analytics/widgets.json
  def widgets
    configs = current_user.widget_configs.order(:created_at)
    render json: configs.map(&:as_widget_json)
  end

  # GET /analytics/widget_items?source_type=Event
  def widget_items
    klass = WidgetConfig::SOURCE_CLASSES[params[:source_type]]&.constantize
    return render json: [] unless klass
    items = klass.where(user: current_user, trackable: true)
                 .order(:title)
                 .map { |i| { id: i.id, name: i.title } }
    render json: items
  end

  MAX_DAILY_MINUTES = 16 * 60 # 16-hour day = 100%

  def show
    @week_start = Date.current.beginning_of_week
    @week_end   = Date.current.end_of_week
    range_start = @week_start.beginning_of_day
    range_end   = @week_end.end_of_day

    occurrences = calendar_occurrences_for_range(range_start, range_end)

    now = Time.current

    events    = occurrences.select { |o| o.is_a?(Event::Occurrence) }
    courses   = occurrences.select { |o| o.is_a?(Course::Occurrence) }
    shifts    = occurrences.select { |o| o.is_a?(WorkShift::Occurrence) }
    deadlines = occurrences.select { |o| o.is_a?(CourseItem) }

    @event_count    = events.count
    @course_count   = courses.count
    @shift_count    = shifts.count
    @deadline_count = deadlines.count
    @total_count    = occurrences.count

    @events_past        = events.count    { |o| o.starts_at < now }
    @events_upcoming    = events.count    { |o| o.starts_at >= now }
    @courses_past       = courses.count   { |o| o.starts_at < now }
    @courses_upcoming   = courses.count   { |o| o.starts_at >= now }
    @shifts_past        = shifts.count    { |o| o.starts_at < now }
    @shifts_upcoming    = shifts.count    { |o| o.starts_at >= now }
    @deadlines_past     = deadlines.count { |o| o.starts_at < now }
    @deadlines_upcoming = deadlines.count { |o| o.starts_at >= now }

    # Per-day breakdown (Mon–Sun)
    @days = (@week_start..@week_end).to_a
    @daily_stats = @days.map do |day|
      timed_occs = occurrences.select do |o|
        !o.is_a?(CourseItem) && o.starts_at.to_date == day
      end

      timed_minutes = timed_occs.sum do |o|
        next 0 unless o.ends_at && o.starts_at
        [ (o.ends_at - o.starts_at) / 60.0, 0 ].max.to_i
      end

      deadlines = occurrences.count { |o| o.is_a?(CourseItem) && o.starts_at.to_date == day }

      {
        date:       day,
        minutes:    timed_minutes,
        item_count: timed_occs.count,
        deadlines:  deadlines,
        pct:        [ (timed_minutes.to_f / MAX_DAILY_MINUTES * 100), 100 ].min.round(1)
      }
    end

    @total_minutes = @daily_stats.sum { |s| s[:minutes] }
    @busiest_day   = @daily_stats.max_by { |s| s[:minutes] }

    # Donut chart segments (skip zero-count types)
    @chart_segments = [
      { label: "Events",      count: @event_count,    color: "#60a5fa" },
      { label: "Courses",     count: @course_count,   color: "#34d399" },
      { label: "Work Shifts", count: @shift_count,    color: "#a78bfa" },
      { label: "Deadlines",   count: @deadline_count, color: "#fbbf24" }
    ].reject { |s| s[:count].zero? }
  end
end
