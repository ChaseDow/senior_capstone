class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current

    week_start  = @start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    base_events = current_user.events
      .where("starts_at <= ?", range_end)
      .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
      .order(starts_at: :asc)

    @events = base_events
    @occurrences = base_events.flat_map { |e| e.occurrences_between(range_start, range_end) }
                            .sort_by(&:starts_at)

    return unless turbo_frame_request?

    render partial: "dashboard/calendar_frame",
          locals: { events: @occurrences, start_date: @start_date }
  end
end
