# frozen_string_literal:true

class ScheduleBlock < ApplicationController
    layout "app_shell"
    
    @items_by_day = Array.new(7) { Array.new(10) } #limited to 10 events per day arbitrarily, rows indicate days, items_by_day[0] = sunday
    def show, end
end