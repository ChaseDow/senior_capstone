class EventOccurrencesController < ApplicationController
  before_action :authenticate_user!

  # GET /event_occurrences?event_id=123
  def index
    refresh_occurrences(params[:event_id])

    occurrences = current_user.event_occurrences
                              .for_event(params[:event_id])
                              .past
                              .order(:occurs_on)

    render json: occurrences.map { |o|
      {
        id:              o.id,
        occurs_on:       o.occurs_on,
        occurs_on_label: o.occurs_on.strftime("%-b %-d, %Y"),
        day_of_week:     o.occurs_on.strftime("%A"),
        completed:       o.completed,
        completed_at:    o.completed_at,
        duration_hours:  o.duration_hours,
      }
    }
  end

  # GET /event_occurrences/summary?event_id=123&goal_hours=10
  def summary
    refresh_occurrences(params[:event_id])

    occurrences = current_user.event_occurrences
                              .for_event(params[:event_id])
                              .past

    completed  = occurrences.completed
    goal_hours = params[:goal_hours].to_f
    total_past = occurrences.count
    done_count = completed.count
    done_hours = completed.sum(:duration_hours).to_f
    pct_hours  = goal_hours > 0 ? [ (done_hours / goal_hours * 100).round, 100 ].min : 0
    pct_events = total_past > 0 ? (done_count.to_f / total_past * 100).round : 0

    render json: {
      event_id:        params[:event_id],
      goal_hours:      goal_hours,
      done_hours:      done_hours.round(1),
      done_count:      done_count,
      total_past:      total_past,
      pct_hours:       pct_hours,
      pct_events:      pct_events,
      remaining_hours: [ goal_hours - done_hours, 0 ].max.round(1),
    }
  end

  # PATCH /event_occurrences/:id
  def update
    occurrence = current_user.event_occurrences.find(params[:id])

    if params[:completed].to_s == "true"
      occurrence.mark_complete!
    else
      occurrence.mark_incomplete!
    end

    render json: {
      id:           occurrence.id,
      completed:    occurrence.completed,
      completed_at: occurrence.completed_at,
    }
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  # Idempotent self-heal: generates any missing past occurrences and corrects
  # duration_hours on existing ones if the source event's duration changed.
  # Only runs when the user actually owns a tracking entry for this event.
  def refresh_occurrences(event_id)
    return if event_id.blank?
    return unless current_user.tracking_entries.exists?(trackable_type: "Event", trackable_id: event_id)
    event = Event.find_by(id: event_id)
    event&.generate_past_occurrences_for(current_user)
  end
end
