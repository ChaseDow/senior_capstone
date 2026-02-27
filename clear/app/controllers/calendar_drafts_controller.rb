# frozen_string_literal: true

class CalendarDraftsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def index
    @drafts = current_user.calendar_drafts.order(created_at: :desc)
  end

  def create
    start_date =
      begin
        params[:start_date].present? ? Date.parse(params[:start_date].to_s) : Date.current
      rescue ArgumentError
        Date.current
      end

    draft =
      current_user.calendar_drafts.create!(
        title: params[:title].presence || "What-if Draft",
        status: :open
      )

    # IMPORTANT: keep draft mode "sticky" even if turbo requests drop draft_id
    set_active_draft!(draft)

    respond_to do |format|
      format.html do
        redirect_to dashboard_path(start_date: start_date, draft_id: draft.id),
                    notice: "Draft started."
      end

      format.turbo_stream do
        occurrences =
          Dashboard::OccurrencesForWeek.call(
            user: current_user,
            start_date: start_date,
            draft: draft
          )

        render turbo_stream: turbo_stream.replace(
          "dashboard_calendar",
          partial: "dashboard/calendar_frame",
          locals: { events: occurrences, start_date: start_date, draft: draft }
        )
      end
    end
  end

  def discard
    draft = current_user.calendar_drafts.open.find(params[:id])
    draft.update!(status: :discarded)

    # IMPORTANT: leaving draft mode should clear the sticky draft
    clear_active_draft!

    start_date =
      begin
        params[:start_date].present? ? Date.parse(params[:start_date].to_s) : Date.current
      rescue ArgumentError
        Date.current
      end

    respond_to do |format|
      format.html do
        redirect_to dashboard_path(start_date: start_date),
                    notice: "Draft discarded."
      end

      format.turbo_stream do
        occurrences =
          Dashboard::OccurrencesForWeek.call(
            user: current_user,
            start_date: start_date,
            draft: nil
          )

        render turbo_stream: turbo_stream.replace(
          "dashboard_calendar",
          partial: "dashboard/calendar_frame",
          locals: { events: occurrences, start_date: start_date, draft: nil }
        )
      end
    end
  end

  def apply
    draft = current_user.calendar_drafts.open.find(params[:id])

    CalendarDrafts::Apply.call!(draft: draft)
    draft.update!(status: :applied)

    # IMPORTANT: leaving draft mode should clear the sticky draft
    clear_active_draft!

    start_date =
      begin
        params[:start_date].present? ? Date.parse(params[:start_date].to_s) : Date.current
      rescue ArgumentError
        Date.current
      end

    respond_to do |format|
      format.html do
        redirect_to dashboard_path(start_date: start_date),
                    notice: "Draft applied."
      end

      format.turbo_stream do
        occurrences =
          Dashboard::OccurrencesForWeek.call(
            user: current_user,
            start_date: start_date,
            draft: nil
          )

        render turbo_stream: turbo_stream.replace(
          "dashboard_calendar",
          partial: "dashboard/calendar_frame",
          locals: { events: occurrences, start_date: start_date, draft: nil }
        )
      end
    end
  end
end
