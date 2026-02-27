class DashboardController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def show
    @start_date =
      begin
        params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
      rescue ArgumentError
        Date.current
      end

    week_start  = @start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    @occurrences = calendar_occurrences_for_range(range_start, range_end)

    return unless turbo_frame_request?

    render partial: "dashboard/calendar_frame",
           locals: { events: @occurrences, start_date: @start_date }
  end

  def agenda
    @date =
      begin
        params[:date].present? ? Date.parse(params[:date]) : Date.current
      rescue ArgumentError
        Date.current
      end

    range_start = @date.beginning_of_day
    range_end   = @date.end_of_day

    @occurrences = calendar_occurrences_for_range(range_start, range_end)

    render "dashboard/agenda"
  end

  private

  def occurrences_for_range(range_start, range_end)
    base_events = current_user.events

    non_recurring_events = base_events.where(recurring: false)
                                      .where(starts_at: range_start..range_end)

    recurring_events = base_events.where(recurring: true)
                                  .where("starts_at <= ?", range_end)
                                  .where("repeat_until >= ?", range_start.to_date)


    event_occurrences = (non_recurring_events + recurring_events).flat_map { |e| e.occurrences_between(range_start, range_end) }

    base_courses = current_user.courses
      .where("start_date <= ?", range_end.to_date)
      .where("end_date >= ?", range_start.to_date)
      .order(start_date: :asc)

    course_occurrences =
      base_courses.flat_map { |c| c.occurrences_between(range_start, range_end) }

    course_items =
      CourseItem
        .joins(:course)
        .where(courses: { user_id: current_user.id })
        .where(due_at: range_start..range_end)
        .includes(:course)

    (event_occurrences + course_occurrences + course_items.to_a)
      .sort_by(&:starts_at)
  end
end
