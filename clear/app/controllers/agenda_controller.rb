class AgendaController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def index
    @target_date = params[:date].present? ? Date.parse(params[:date]) : Date.current
   
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : @target_date
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : start_date

    if end_date < start_date
      flash.now[:alert] = "End date must be on or after the start date"
      end_date = start_date
      start_date = end_date
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

    per_page = 10

    @page = params[:page].to_i
    @page = 1 if @page < 1

    all_entries = @agenda_by_date.values.flatten.sort_by { |e| e[:time_sortable] }

    @total_pages = (all_entries.length.to_f / per_page).ceil
    @total_pages = 1 if @total_pages < 1
    @page = @total_pages if @page > @total_pages

    page_entries = all_entries.slice((@page - 1) * per_page, per_page) || []

    @paged_agenda_by_date = page_entries.group_by do |entry|
      entry[:time_sortable].to_date
end

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

  # helper function for 
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
