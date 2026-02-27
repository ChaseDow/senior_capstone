# frozen_string_literal: true

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

    @draft = current_calendar_draft
    @occurrences = dashboard_week_occurrences_for(@start_date, draft: @draft)

    return unless turbo_frame_request?

    render partial: "dashboard/calendar_frame",
           locals: { events: @occurrences, start_date: @start_date, draft: @draft }
  end

  def agenda
    @date =
      begin
        params[:date].present? ? Date.parse(params[:date]) : Date.current
      rescue ArgumentError
        Date.current
      end

    @draft = current_calendar_draft

    # If you want agenda to also show draft overlay for the day:
    start_date = @date.beginning_of_week.to_date
    week_occurrences = dashboard_week_occurrences_for(start_date, draft: @draft)
    @occurrences = week_occurrences.select { |o| o.starts_at.in_time_zone.to_date == @date }

    render "dashboard/agenda"
  end
end
