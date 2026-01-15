class AgendaController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_page_title

  def index
    @events = current_user.events.order(starts_at: :asc)
    @courses = current_user.courses.order(starts_at: :asc)
  end

  def show; end

  def new
    @event = current_user.events.new
  end

  private

  def set_page_title
    @page_title =
      case action_name
      when "index" then "Events"
      else "Event"
      end
  end

  def set_event
    @event = current_user.events.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:title, :starts_at, :ends_at, :location, :description)
  end
end
