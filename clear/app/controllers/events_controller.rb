class EventsController < ApplicationController
  layout "app_shell"

  before_action :set_page_title
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @events = Event.order(starts_at: :asc)
  end

  def show; end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      redirect_to event_path(@event), notice: "Event created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @event.update(event_params)
      redirect_to event_path(@event), notice: "Event updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: "Event deleted."
  end

  private

  def set_page_title
    @page_title =
      case action_name
      when "index" then "Events"
      when "new", "create" then "New Event"
      when "edit", "update" then "Edit Event"
      else "Event"
      end
  end

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:title, :starts_at, :ends_at, :location, :description)
  end
end
