# frozen_string_literal: true

class ScheduleController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def week
    reference_date = params[:date]&.to_date || Date.current
    @week_start = reference_date.beginning_of_week(:monday)
    @days = (0..6).map { |i| @week_start + i.days }

    items = current_user.events.where(
      starts_at: @week_start..(@week_start + 6.days).end_of_day
    )

    @items_by_day = items.group_by { |item| item.starts_at.to_date }
    @items_by_day.transform_values! { |day_items| day_items.sort_by(&:starts_at) }
  end

  def show; end
end
