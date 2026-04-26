class TrackingEntriesController < ApplicationController
  before_action :authenticate_user!

  def index
    entries = current_user.tracking_entries.order(created_at: :desc)
    render json: entries.as_json(only: %i[id trackable_type trackable_id trackable_label completed completed_at])
  end

  def create
    entry = current_user.tracking_entries.build(tracking_entry_params)
    entry.trackable_label = resolve_label(params.dig(:tracking_entry, :trackable_type),
                                          params.dig(:tracking_entry, :trackable_id))

    if entry.save
      entry.trackable.generate_past_occurrences_for(current_user) if entry.trackable_type == "Event"
      render json: entry.as_json(only: %i[id trackable_type trackable_id trackable_label completed completed_at]),
             status: :created
    else
      render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    entry = current_user.tracking_entries.find(params[:id])

    if params[:completed].to_s == "true"
      entry.mark_complete!
    else
      entry.mark_incomplete!
    end

    render json: entry.as_json(only: %i[id trackable_type trackable_id trackable_label completed completed_at])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def destroy
    entry = current_user.tracking_entries.find(params[:id])
    entry.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def tracking_entry_params
    params.require(:tracking_entry).permit(:trackable_type, :trackable_id)
  end

  def resolve_label(type, id)
    case type
    when "Event"      then Event.find(id).title
    when "Course"     then Course.find(id).title
    when "CourseItem" then CourseItem.find(id).title
    when "WorkShift"  then WorkShift.find(id).title
    else "Unknown"
    end
  rescue ActiveRecord::RecordNotFound
    "Unknown"
  end
end
