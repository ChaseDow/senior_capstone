# frozen_string_literal: true

class EventsController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @events = current_user.events.order(starts_at: :asc)
  end

  def show
    return unless turbo_frame_request?

    render partial: "events/drawer_detail",
           locals: { event: @event, start_date: params[:start_date], draft_id: current_calendar_draft&.id }
  end

  def new
    start_time = params[:start_time].present? ? Time.zone.parse(params[:start_time]) : nil
    @event = current_user.events.new(starts_at: start_time)
  end

  def create
    if current_calendar_draft.present?
      create_draft_op!(
        op_type: :add,
        target_type: "Event",
        target_id: nil,
        patch: event_params.to_h
      )

      start_date = parse_start_date(params[:start_date])
      occurrences = dashboard_week_occurrences_for(start_date)

      respond_to do |format|
        format.html do
          redirect_to dashboard_path(start_date: start_date, draft_id: current_calendar_draft.id),
                      notice: "Draft event added."
        end

        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: current_calendar_draft }
            ),
            turbo_stream.update("event_drawer", "")
          ]
        end
      end

      return
    end

    @event = current_user.events.new(event_params)

    if @event.save
      respond_to do |format|
        format.html { redirect_to event_path(@event), notice: "Event created." }

        format.turbo_stream do
          start_date = parse_start_date(params[:start_date])
          occurrences = dashboard_week_occurrences_for(start_date, draft: nil)

          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: nil }
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
            locals: { event: @event, start_date: params[:start_date], draft_id: current_calendar_draft&.id }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    return unless turbo_frame_request?

    render partial: "events/drawer_edit",
           locals: { event: @event, start_date: params[:start_date], draft_id: current_calendar_draft&.id }
  end

  def update
    if current_calendar_draft.present?
      create_draft_op!(
        op_type: :change,
        target_type: "Event",
        target_id: @event.id,
        patch: event_params.to_h
      )

      start_date = parse_start_date(params[:start_date])
      occurrences = dashboard_week_occurrences_for(start_date)

      respond_to do |format|
        format.html do
          redirect_to dashboard_path(start_date: start_date, draft_id: current_calendar_draft.id),
                      notice: "Draft change recorded."
        end

        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: current_calendar_draft }
            ),
            turbo_stream.update("event_drawer", "")
          ]
        end
      end

      return
    end

    if @event.update(event_params)
      respond_to do |format|
        format.html { redirect_to event_path(@event), notice: "Event updated." }

        format.turbo_stream do
          start_date = parse_start_date(params[:start_date])
          occurrences = dashboard_week_occurrences_for(start_date, draft: nil)

          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: nil }
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
            locals: { event: @event, start_date: params[:start_date], draft_id: current_calendar_draft&.id }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    if current_calendar_draft.present?
      create_draft_op!(
        op_type: :remove,
        target_type: "Event",
        target_id: @event.id,
        patch: {}
      )

      start_date = parse_start_date(params[:start_date])
      occurrences = dashboard_week_occurrences_for(start_date)

      respond_to do |format|
        format.html do
          redirect_to dashboard_path(start_date: start_date, draft_id: current_calendar_draft.id),
                      notice: "Draft delete recorded."
        end

        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: current_calendar_draft }
            ),
            turbo_stream.update("event_drawer", "")
          ]
        end
      end

      return
    end

    @event.destroy!

    respond_to do |format|
      format.html { redirect_to events_path, notice: "Event deleted." }

      format.turbo_stream do
        start_date = parse_start_date(params[:start_date])
        occurrences = dashboard_week_occurrences_for(start_date, draft: nil)

        render turbo_stream: [
          turbo_stream.replace(
            "dashboard_calendar",
            partial: "dashboard/calendar_frame",
            locals: { events: occurrences, start_date: start_date, draft: nil }
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

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  def create_draft_op!(op_type:, target_type:, target_id:, patch:)
    draft = current_calendar_draft
    raise ActiveRecord::RecordNotFound, "Draft not found" unless draft

    draft.operations.create!(
      op_type: op_type,
      target_type: target_type,
      target_id: target_id,
      status: :pending,
      position: (draft.operations.maximum(:position) || -1) + 1,
      payload: { "patch" => patch }
    )
  end

  def event_params
    params.require(:event).permit(
      :title,
      :starts_at,
      :ends_at,
      :location,
      :priority,
      :description,
      :color,
      :recurring,
      :repeat_until,
      repeat_days: []
    )
  end
end
