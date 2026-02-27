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

    @occurrences = occurrences_for_range(range_start, range_end)

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

    @occurrences = occurrences_for_range(range_start, range_end)

    render "dashboard/agenda"
  end
end
