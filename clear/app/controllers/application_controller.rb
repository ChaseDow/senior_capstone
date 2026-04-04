class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || authenticated_root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  private

  def calendar_occurrences_for_range(range_start, range_end, draft: nil)
    base_events = current_user.events
      .where(project_id: nil)
      .where("starts_at <= ?", range_end)
      .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
      .order(starts_at: :asc)

    event_occurrences =
      base_events.flat_map { |e| e.occurrences_between(range_start, range_end) }

    base_courses = current_user.courses
      .where("start_date <= ?", range_end.to_date)
      .where("end_date >= ?", range_start.to_date)
      .order(start_date: :asc)

    course_occurrences =
      base_courses.flat_map { |c| c.occurrences_between(range_start, range_end) }

    base_work_shifts = current_user.work_shifts.active
      .where("repeat_until IS NULL OR repeat_until >= ?", range_start.to_date)

    work_shift_occurrences =
      base_work_shifts.flat_map { |ws| ws.occurrences_between(range_start, range_end) }

    course_items =
      CourseItem
        .joins(:course)
        .where(courses: { user_id: current_user.id })
        .where(due_at: range_start..range_end)
        .includes(:course)

    result = (event_occurrences + course_occurrences + work_shift_occurrences + course_items.to_a).sort_by(&:starts_at)

    draft&.operation_count&.positive? ? draft.build_preview_occurrences(result, range_start, range_end) : result
  end

  def current_user_draft
    return @current_user_draft if defined?(@current_user_draft)

    @current_user_draft = if session[:calendar_draft_mode]
      draft = CalendarDraft.find_by(user: current_user)
      session.delete(:calendar_draft_mode) if draft.nil?
      draft
    end
  end
end
