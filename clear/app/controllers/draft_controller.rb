# frozen_string_literal: true

class DraftController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  include Pagy::Method
  include DraftEventOccurrences

  def enter
    CalendarDraft.find_or_create_by!(user: current_user)
    session[:calendar_draft_mode] = true

    render_calendar_turbo_stream(draft: current_user_draft)
  end

  def apply
    draft = current_user_draft
    if draft
      begin
        draft.apply!(current_user)
      rescue => e
        flash.now[:alert] = "Could not apply draft: #{e.message}"
      end
      session.delete(:calendar_draft_mode)
    end

    render_calendar_turbo_stream(draft: nil)
  end

  def discard
    draft = current_user_draft
    if draft
      draft.discard!
      session.delete(:calendar_draft_mode)
    end

    render_calendar_turbo_stream(draft: nil)
  end

  # Toggling out of Draft Mode
  def exit
    session.delete(:calendar_draft_mode)
    render_calendar_turbo_stream(draft: nil)
  end

  # For viewing changes to the Draft
  def changes
    start_date = parse_start_date(params[:start_date]).iso8601
    draft = current_user_draft
    all_rows = draft.present? ? build_change_rows(draft.operations, start_date: start_date) : []
    @pagy, rows = pagy(:offset, all_rows, limit: 10)

    render partial: "draft/changes_modal",
           locals: {
             draft: draft,
             rows: rows,
             start_date: start_date,
             pagy: @pagy
           }
  end

  # For restoring changes made while in Draft Mode
  def restore
    start_date = parse_start_date(params[:start_date])
    draft = current_user_draft

    if draft.present?
      idx = params[:index].to_i
      ops = draft.operations.dup
      ops.delete_at(idx) if idx >= 0 && idx < ops.length
      draft.update!(operations: ops)
    end

    render_calendar_turbo_stream(draft: current_user_draft, start_date: start_date, include_changes_modal: true)
  end

  private

  # start_date and include_changes_modal are optional parameters.
  # start_date is for re-rendering starting from the day you're restoring (so if you're restoring an event in the previous week the calendar actually updates)
  # include_changes_modal is for updating the draft changes modal which is triggered whenever you press view on the draft banner
  def render_calendar_turbo_stream(draft:, start_date: nil, include_changes_modal: false)
    start_date  = start_date || parse_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    occurrences = calendar_occurrences_for_range(range_start, range_end, draft: draft)
    if include_changes_modal
      all_rows = draft.present? ? build_change_rows(draft.operations, start_date: start_date.iso8601) : []
      @pagy, rows = pagy(:offset, all_rows, limit: 10)
    end

    streams = []
    if include_changes_modal
      streams << turbo_stream.replace(
        "draft_changes_modal",
        partial: "draft/changes_modal",
        locals: { draft: draft, rows: rows, start_date: start_date.iso8601, pagy: @pagy }
      )
    end
    streams += [
      turbo_stream.replace(
        "dashboard_calendar",
        partial: "dashboard/calendar_frame",
        locals: { events: occurrences, start_date: start_date, draft: draft }
      ),
      turbo_stream.replace(
        "draft_toggle",
        partial: "draft/toggle",
        locals: { start_date: start_date.iso8601, active_draft: draft }
      ),
      turbo_stream.replace(
        "draft_banner",
        partial: "draft/banner",
        locals: { start_date: start_date.iso8601, active_draft: draft }
      ),
      build_events_list_stream(draft: draft)
    ].compact
    render turbo_stream: streams
  end

  # This is for building the cards seen in the Draft View Changes Modal
  def build_change_rows(operations, start_date:)
    operations.each_with_index.map do |op, idx|
      type   = op["type"].to_s
      model  = op["model"].to_s
      data   = op["data"] || {}
      record = op["id"].present? ? draft_record_for(model, op["id"]) : nil

      {
        index: idx,
        id: op["id"] || op["temp_id"] || "op_#{idx}",
        action: type,
        model: model,
        color: data["color"].presence || record&.try(:color).presence,
        title: data["title"].presence || record&.title.presence || "Untitled",
        open_path: operation_open_path(type, model, data, record, start_date: start_date, temp_id: op["temp_id"])
      }
    end
  end

  # Getting the id for the cards
  def draft_record_for(model, id)
    case model
    when "event" then current_user.events.find_by(id: id)
    when "course" then current_user.courses.find_by(id: id)
    end
  end

  # This is for finding the path whenever the user presses edit
  def operation_open_path(type, model, data, record, start_date:, temp_id: nil)
    case model
    when "event"
      return edit_event_path(record, start_date: start_date, source: "draft_changes") if record.present?
      return unless type == "create"
      new_event_path(start_time: data["starts_at"], start_date: start_date, source: "draft_changes", temp_id: temp_id)
    when "course"
      return edit_course_path(record, start_date: start_date) if record.present?
      return unless type == "create"
      new_course_path(start_date: start_date)
    end
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  # For replacing the turbo fromes on events index page when events are getting draft changes
  def build_events_list_stream(draft:)
    if draft.present? && draft.operation_count.positive?
      items = draft_event_occurrences_for(draft)
      pagy_obj, page_events = pagy(:offset, items, limit: 10)
    else
      events = current_user.events.order(starts_at: :asc)
      pagy_obj, page_events = pagy(events, limit: 10)
    end

    turbo_stream.replace(
      "events_list",
      partial: "events/list_frame",
      locals: { events: page_events, q: nil, pagy: pagy_obj }
    )
  end

end
