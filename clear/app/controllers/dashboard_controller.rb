class DashboardController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def show
    @start_date =
      begin
        if turbo_frame_request? && params[:start_date].present?
          Date.parse(params[:start_date])
        else
          Date.current
        end
      rescue ArgumentError
        Date.current
      end

    week_start  = @start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    @course_filter_id = params[:course_id].presence
    @courses          = current_user.courses.order(:title)

    @draft       = current_user_draft
    @occurrences = calendar_occurrences_for_range(range_start, range_end, draft: @draft, course_id: @course_filter_id)

    # Monthly view data
    month_start = @start_date.beginning_of_month
    month_end   = @start_date.end_of_month
    @month_occurrences = calendar_occurrences_for_range(
      month_start.beginning_of_day, month_end.end_of_day, draft: @draft, course_id: @course_filter_id
    )
    @month_events_by_date = group_occurrences_by_date(@month_occurrences)
    @month_date = @start_date

    now = Time.current
    next_occurrences = calendar_occurrences_for_range(now, now + 7.days)
    @next_occurrence = next_occurrences.find { |o| o.starts_at > now }

    return unless turbo_frame_request?

    render partial: "dashboard/calendar_frame",
           locals: { events: @occurrences, start_date: @start_date, draft: @draft,
                     month_events_by_date: @month_events_by_date, month_date: @month_date,
                     courses: @courses, course_filter_id: @course_filter_id }
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

    now = Time.current
    next_occurrences = calendar_occurrences_for_range(now, now + 7.days)
    @next_occurrence = next_occurrences.find { |o| o.starts_at > now }

    render "dashboard/agenda"
  end

  private

  def group_occurrences_by_date(occurrences)
    grouped = Hash.new { |h, k| h[k] = [] }
    occurrences.each do |occ|
      grouped[occ.starts_at.in_time_zone.to_date] << occ
    end
    grouped
  end

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
