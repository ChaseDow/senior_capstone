class CalendarController < ApplicationController
  def show
    # pick date from params or default to today
    @date = params[:date]&.to_date || Date.today

    # load events for the visible month
    @events = Event.where(
      date: @date.beginning_of_month..@date.end_of_month
    )
  end
end
