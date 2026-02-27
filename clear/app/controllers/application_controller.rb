class ApplicationController < ActionController::Base
  protected

  def after_sign_in_path_for(resource)
    authenticated_root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  private

  def calendar_occurrences_for_range(range_start, range_end)
    base_events = current_user.events
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

    course_items =
      CourseItem
        .joins(:course)
        .where(courses: { user_id: current_user.id })
        .where(due_at: range_start..range_end)
        .includes(:course)

    (event_occurrences + course_occurrences + course_items.to_a)
      .sort_by(&:starts_at)
  end
end
