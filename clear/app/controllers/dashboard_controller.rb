# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @start_date = params.fetch(:start_date, Date.current).to_date

    week_start  = @start_date.beginning_of_week
    range_start = Time.zone.local(week_start.year, week_start.month, week_start.day, 0, 0, 0)
    range_end   = (range_start + 6.days).end_of_day

    @events =
      current_user
        .events
        .where(starts_at: range_start..range_end)
        .order(:starts_at)
  end
end
