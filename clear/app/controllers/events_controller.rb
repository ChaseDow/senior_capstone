# frozen_string_literal: true

class EventsController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_event, only: %i[show edit update destroy]
  before_action :load_labels, only: %i[new edit create update]

  def index
    @events = current_user.events.order(starts_at: :asc)
  end

  def show
    return unless turbo_frame_request?

    render partial: "events/drawer_detail",
           locals: { event: @event, start_date: params[:start_date] }
  end

  def new
    start_time = params[:start_time].present? ? Time.zone.parse(params[:start_time]) : nil
    @event = current_user.events.new(starts_at: start_time)
  end

  def create
    @event = current_user.events.new(event_params)

    if @event.save
      respond_to do |format|
        format.html { redirect_to event_path(@event), notice: "Event created." }

        format.turbo_stream do
          unless turbo_frame_request?
            redirect_to event_path(@event), status: :see_other
            next
          end

          start_date = parse_start_date(params[:start_date])
          occurrences = dashboard_occurrences_for(start_date)

          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date }
            ),
            turbo_stream.update("event_drawer", "")
          ]
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "event_drawer",
            partial: "events/drawer_edit",
            locals: { event: @event, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    return unless turbo_frame_request?

    render partial: "events/drawer_edit",
           locals: { event: @event, start_date: params[:start_date] }
  end

  def update
    if @event.update(event_params)
      respond_to do |format|
        format.html { redirect_to event_path(@event), notice: "Event updated." }

        format.turbo_stream do
          unless turbo_frame_request?
            redirect_to event_path(@event), status: :see_other
            next
          end

          start_date = parse_start_date(params[:start_date])
          occurrences = dashboard_occurrences_for(start_date)

          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date }
            ),
            turbo_stream.update("event_drawer", "")
          ]
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "event_drawer",
            partial: "events/drawer_edit",
            locals: { event: @event, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @event.destroy!

    respond_to do |format|
      format.html { redirect_to events_path, notice: "Event deleted." }

      format.turbo_stream do
        unless turbo_frame_request?
          redirect_to events_path, status: :see_other
          next
        end

        start_date = parse_start_date(params[:start_date])
        occurrences = dashboard_occurrences_for(start_date)

        render turbo_stream: [
          turbo_stream.replace(
            "dashboard_calendar",
            partial: "dashboard/calendar_frame",
            locals: { events: occurrences, start_date: start_date }
          ),
          turbo_stream.update("event_drawer", "")
        ]
      end
    end
  end

  private

  def set_event
    @event = current_user.events.find(params[:id])
  end

  def load_labels
    @labels = current_user.labels.order(:name)
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  def dashboard_occurrences_for(start_date)
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    base_events =
      current_user.events
                  .where("starts_at <= ?", range_end)
                  .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
                  .order(starts_at: :asc)

    base_events.flat_map { |e| e.occurrences_between(range_start, range_end) }
              .sort_by(&:starts_at)

    base_courses = current_user.courses
      .where("start_date <= ?", range_end.to_date)
      .where("end_date >= ?", range_start.to_date)
      .order(start_date: :asc)

    course_occurrences =
      base_courses.flat_map { |c| c.occurrences_between(range_start, range_end) }

    (base_events + course_occurrences).sort_by(&:starts_at)
  end

  def event_params
    params.require(:event).permit(
      :title,
      :starts_at,
      :ends_at,
      :location,
      :priority,
      :description,
      :recurring,
      :repeat_until,
      :label_id,
      repeat_days: []
    )
  end
end
