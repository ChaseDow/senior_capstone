# frozen_string_literal: true

class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @events = Event.order(starts_at: :asc)
  end

  def show; end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(events_params)

    if @event.save
      redirect_to event_path(@event), notice: "Event created."

    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @event.update(events_params)
      redirect_to @event, notice: "Event updated."

    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: "Event deleted."
  end

  def set_event
    @event = Event.find(params[:id])
  end

  def events_params
    params.require(:event).permit(:title, :starts_at, :ends_at, :location, :description)
  end
end
