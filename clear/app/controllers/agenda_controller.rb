class AgendaController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_page_title

  def index
  @day = Date.today.strftime("%A")
  day = Date.today.strftime("%A")
  day_to_abbreviation = {"Monday"=> "M", "Tuesday" => "T", "Wednesday" => "W", "Thursday" => "R", "Friday" => "F"}
  @events = current_user.events.where(starts_at: Date.today.all_day)
  @courses = Course.where("meeting_days LIKE ?", ["%",day_to_abbreviation[day],"%"].join)
  
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
