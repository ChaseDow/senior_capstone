# frozen_string_literal:true

class ScheduleController < ApplicationController
    layout "app_shell"
    def week
        reference_date = params[:date]&.to_date || Date.current
        @week_start = reference_date.beginning_of_week(:monday)
        @days = (0..6).map { |i| @week_start + i.days }

        items = Event.where(starts_at: @week_start..(@week_start + 6.days).end_of_day)
        @items_by_day = items.group_by { |item| item.starts_at.to_date }
        @items_by_day.transform_values! do |item|
            item.sort_by(&:starts_at)
        end
    end

    def show; end
end
