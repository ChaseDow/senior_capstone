class AgendaController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_page_title

  def index
  @day = Date.today.strftime("%A")
  day = Date.today.strftime("%A")
  
  day_to_abbreviation = {"Monday"=> "M", "Tuesday" => "T", "Wednesday" => "W", "Thursday" => "R", "Friday" => "F"}
  day_to_int = {"Sunday" => 0, "Monday"=> 1, "Tuesday" => 2, "Wednesday" => 3, "Thursday" => 4, "Friday" => 5, "Saturday" => 6}

  non_recurring_events = current_user.events.where(starts_at: Date.today.all_day)
                         .where(recurring: false)

  recurring_events = current_user.events.where(recurring: true)
                     .where("repeat_until >= ?", Date.today)
                     .where("? = ANY(repeat_days)", day_to_int[day]) 

  @courses = Course.where("meeting_days LIKE ?", ["%",day_to_abbreviation[day],"%"].join)

  @events = non_recurring_events + recurring_events
  
  @agenda = (@events.map { |e| {item: e, type: "Event", time: e.starts_at.strftime("%I:%M %p")}} +
             @courses.map { |c| { item: c, type: "Course", time: c.start_time.strftime("%I:%M %p")}})
             .sort_by {|entry| entry[:time]}
  
  end

  def show; end

  private

  def set_page_title
    @page_title = Agenda
  end

end
