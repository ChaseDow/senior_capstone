# frozen_string_literal: true

class DraftController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

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

  def exit
    session.delete(:calendar_draft_mode)
    render_calendar_turbo_stream(draft: nil)
  end

  private

  def render_calendar_turbo_stream(draft:)
    start_date  = parse_start_date(params[:start_date])
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    occurrences = calendar_occurrences_for_range(range_start, range_end, draft: draft)
    streams = [
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
      )
    ]
    render turbo_stream: streams
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end
end
