class AgendaController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def index
    @target_date =
      begin
        params[:date].present? ? Date.parse(params[:date]) : Date.current
      rescue ArgumentError
        Date.current
      end

    start_date =
      begin
        params[:start_date].present? ? Date.parse(params[:start_date]) : @target_date
      rescue ArgumentError
        @target_date
      end

    end_date =
      begin
        params[:end_date].present? ? Date.parse(params[:end_date]) : start_date
      rescue ArgumentError
        start_date
      end

    if end_date < start_date
      flash.now[:alert] = "End date must be on or after the start date"
      end_date = start_date
    end

    @date_range = start_date..end_date

    range_start = start_date.beginning_of_day
    range_end   = end_date.end_of_day

    occurrences = occurrences_for_range(range_start, range_end)

    @agenda_by_date =
      occurrences
        .sort_by(&:starts_at)
        .group_by { |occ| occ.starts_at.to_date }
        .transform_values { |occs| occs.map { |occ| agenda_entry_for(occ) } }

    @type_param = params[:type]
  end

  private

  def occurrences_for_range(range_start, range_end)
    term = params.dig(:q, :term).to_s.strip
    type = params[:type].to_s

    events =
      current_user.events
        .ransack(term.present? ? { title_or_description_or_location_cont: term } : {})
        .result
        .where("starts_at <= ?", range_end)
        .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)

    courses =
      current_user.courses
        .ransack(term.present? ? { title_or_description_or_location_cont: term } : {})
        .result
        .where("start_date <= ?", range_end.to_date)
        .where("end_date IS NULL OR end_date >= ?", range_start.to_date)

    event_occurrences =
      type == "course" ? [] : events.flat_map { |e| e.occurrences_between(range_start, range_end) }

    course_occurrences =
      type == "event" ? [] : courses.flat_map { |c| c.occurrences_between(range_start, range_end) }

    event_occurrences + course_occurrences
  end

  def agenda_entry_for(occ)
    item =
      if occ.respond_to?(:item)
        occ.item
      elsif occ.respond_to?(:event)
        occ.event
      elsif occ.respond_to?(:course)
        occ.course
      end

    is_course = item.is_a?(Course)

    {
      item: item,
      type: is_course ? "Course" : "Event",
      time: occ.starts_at.strftime("%I:%M %p"),
      time_sortable: occ.starts_at,
      title: item&.title.presence || (is_course ? "(Untitled Course)" : "(Untitled Event)"),
      location: item&.location,
      description: item&.description,
      professor: is_course ? item&.professor : nil,
    }
  end
end
