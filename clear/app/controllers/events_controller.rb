# frozen_string_literal: true

class EventsController < ApplicationController
  include Pagy::Method
  include DraftEventOccurrences

  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @q = params[:q].to_s.strip
    @draft = current_user_draft

    if in_draft_mode?
      items = draft_event_occurrences_for(@draft)
      items = filter_index_items(items, @q) if @q.present?
      @pagy, @events = pagy(:offset, items, limit: 10)
    else
      events = current_user.events.order(starts_at: :asc)
      events = events.where("title ILIKE ?", "%#{@q}%") if @q.present?
      @pagy, @events = pagy(events, limit: 10)
    end
  end

  def show
    return unless turbo_frame_request?

    partial = if request.headers["Turbo-Frame"] == "event_popover"
                "events/popover_detail"
    else
                "events/drawer_detail"
    end

    render partial: partial,
           locals: { event: @event, start_date: params[:start_date] }
  end

  def new
    start_time = params[:start_time].present? ? Time.zone.parse(params[:start_time]) : nil
    @event = current_user.events.new(starts_at: start_time)
    if in_draft_mode? && params[:source] == "draft_changes" && params[:temp_id].present?
      op = current_user_draft&.operations&.reverse_each&.find { |o| o["type"] == "create" && o["model"] == "event" && o["temp_id"].to_s == params[:temp_id].to_s }
      data = op["data"] if op
      @event = current_user.events.new(data) if data.present?
    end

    if params[:project_id].present?
      @project = current_user.projects.find(params[:project_id])
      @event.project = @project
    end

    return unless draft_modal_request? && turbo_frame_request? && request.headers["Turbo-Frame"] != "_top"

    render partial: "events/modal_edit",
           locals: { event: @event, start_date: params[:start_date] }
  end

  def create
    if in_draft_mode? && event_params[:project_id].blank?
      @event = current_user.events.new(event_params)
      unless @event.valid?
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: draft_modal_request? ? turbo_stream.replace(
              "draft_changes_modal",
              partial: "events/modal_edit",
              locals: { event: @event, start_date: params[:start_date] }
            ) : turbo_stream.replace(
              "event_drawer",
              partial: "events/drawer_edit",
              locals: { event: @event, start_date: params[:start_date] }
            ), status: :unprocessable_entity
          end
        end
        return
      end

      if params[:source] == "draft_changes" && params[:temp_id].present?
        updated = current_user_draft.update_create("event", params[:temp_id], event_params.to_h)
        current_user_draft.add_create("event", event_params.to_h) unless updated
      else
        current_user_draft.add_create("event", event_params.to_h)
      end
      return render_draft_calendar_update
    end

    @event = current_user.events.new(event_params)
    if params[:event][:project_id].present?
      @event.project = current_user.projects.find(params[:event][:project_id])
    end

    if @event.save
      respond_to do |format|
        format.html { redirect_to event_path(@event), notice: "Event created." }

        format.turbo_stream do
          unless turbo_frame_request?
            redirect_to event_path(@event), status: :see_other
            next
          end

          start_date  = parse_start_date(params[:start_date])
          week_start  = start_date.beginning_of_week
          range_start = week_start.beginning_of_day
          range_end   = (week_start + 6.days).end_of_day
          occurrences = calendar_occurrences_for_range(range_start, range_end)

          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: nil }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
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
    if in_draft_mode? && @event.project_id.blank?
      op = current_user_draft&.operations&.reverse_each&.find { |o| o["type"] == "update" && o["model"] == "event" && o["id"].to_i == @event.id }
      data = op["data"] if op
      @event.assign_attributes(data) if data.present?
    end

    return unless turbo_frame_request? && request.headers["Turbo-Frame"] != "_top"

    render partial: (draft_modal_request? ? "events/modal_edit" : "events/drawer_edit"),
           locals: { event: @event, start_date: params[:start_date] }
  end

  def update
    project = @event.project
    if in_draft_mode? && @event.project_id.blank? && event_params[:project_id].blank?
      attrs = event_params.to_h
      attrs["repeat_days"] = [] if attrs["recurring"] && !params[:event]&.key?(:repeat_days)

      @event.assign_attributes(attrs)
      unless @event.valid?
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: draft_modal_request? ? turbo_stream.replace(
              "draft_changes_modal",
              partial: "events/modal_edit",
              locals: { event: @event, start_date: params[:start_date] }
            ) : turbo_stream.replace(
              "event_drawer",
              partial: "events/drawer_edit",
              locals: { event: @event, start_date: params[:start_date] }
            ), status: :unprocessable_entity
          end
        end
        return
      end

      current_user_draft.add_update("event", @event.id, attrs)
      return render_draft_calendar_update
    end

    if @event.update(event_params)
      respond_to do |format|
        if project.present?
          format.html { redirect_to project_path(project), notice: "Event updated." }
        else
          format.html { redirect_to dashboard_path, notice: "Event updated." }
        end


        format.turbo_stream do
          unless turbo_frame_request?
            redirect_to event_path(@event), status: :see_other
            next
          end

          start_date  = parse_start_date(params[:start_date])
          week_start  = start_date.beginning_of_week
          range_start = week_start.beginning_of_day
          range_end   = (week_start + 6.days).end_of_day
          occurrences = calendar_occurrences_for_range(range_start, range_end)

          if project.present?
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: project.occurrences, start_date: start_date, draft: nil }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", ""),
            turbo_stream.update("event_popover", "")
          ]
          else
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: nil }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", ""),
            turbo_stream.update("event_popover", "")
          ]
          end
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

  def destroy_all
    if in_draft_mode?
      draft = current_user_draft
      event_ids = current_user.events.pluck(:id)

      next_ops = draft.operations.reject do |op|
        next false unless op["model"] == "event"

        op["type"] == "create" || event_ids.include?(op["id"].to_i)
      end
      delete_ops = event_ids.map { |id| { "type" => "delete", "model" => "event", "id" => id } }
      draft.update!(operations: next_ops + delete_ops)

      return render_draft_calendar_update
    end

    current_user.events.destroy_all
    redirect_to events_path, notice: "All events deleted."
  end

  def destroy
    project =  @event.project
    if in_draft_mode? && @event.project_id.blank?
      current_user_draft.add_delete("event", @event.id)
      return render_draft_calendar_update
    end

    if @event.recurring? && params[:scope] == "single"
      excluded_date = parse_start_date(params[:start_date])
      @event.event_exceptions.find_or_create_by!(excluded_date: excluded_date)
      notice = "This occurrence was removed."
    else
      @event.destroy!
      notice = "Event deleted."
    end

    respond_to do |format|
      format.html { redirect_to events_path, notice: notice }

      format.turbo_stream do
        unless turbo_frame_request?
          redirect_to events_path, status: :see_other
          next
        end

        start_date  = parse_start_date(params[:start_date])
        week_start  = start_date.beginning_of_week
        range_start = week_start.beginning_of_day
        range_end   = (week_start + 6.days).end_of_day
        occurrences = calendar_occurrences_for_range(range_start, range_end)

        if project.present?
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: project.occurrences_for_week(start_date), start_date: start_date, draft: nil }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", ""),
            turbo_stream.update("event_popover", "")
          ]
        else
          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date, draft: nil }
            ),
            turbo_stream.replace("agenda_list", partial: "agenda/list"),
            turbo_stream.update("event_drawer", ""),
            turbo_stream.update("event_popover", "")
          ]
        end
      end
    end
  end

  private

  def set_event
    @event = current_user.events.find(params[:id])
  end

  def in_draft_mode?
    session[:calendar_draft_mode] && current_user_draft.present?
  end

  def render_draft_calendar_update
    draft       = current_user_draft
    start_date  = parse_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    occurrences = calendar_occurrences_for_range(range_start, range_end, draft: draft)
    items = draft_event_occurrences_for(draft)
    events_pagy, events = pagy(:offset, items, limit: 10)

    respond_to do |format|
      format.html { redirect_to dashboard_path(start_date: start_date.iso8601), notice: "Draft updated." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "dashboard_calendar",
            partial: "dashboard/calendar_frame",
            locals: { events: occurrences, start_date: start_date, draft: draft }
          ),
          turbo_stream.replace(
            "events_list",
            partial: "events/list_frame",
            locals: { events: events, q: nil, pagy: events_pagy }
          ),
          turbo_stream.replace("agenda_list", partial: "agenda/list"),
          (draft_modal_request? ? turbo_stream.replace(
            "draft_changes_modal",
            partial: "draft/changes_modal_frame",
            locals: { start_date: start_date.iso8601 }
          ) : nil),
          turbo_stream.update("event_drawer", ""),
          turbo_stream.update("event_popover", "")
        ].compact
      end
    end
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  def event_params
    params.require(:event).permit(
      :title, :starts_at, :ends_at, :duration_minutes, :location, :priority,
      :description, :color, :recurring, :repeat_until, :project_id,
      repeat_days: []
    )
  end

  def draft_modal_request?
    params[:source] == "draft_changes"
  end
end
