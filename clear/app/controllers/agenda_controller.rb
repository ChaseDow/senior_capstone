class AgendaController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  include Pagy::Method

  def index
    @target_date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    start_date =
      if params[:start_date].present?
        Date.parse(params[:start_date])
      else
        @target_date
      end

    end_date =
      if params[:end_date].present?
        Date.parse(params[:end_date])
      else
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

    agenda_by_date = occurrences.sort_by(&:starts_at)
                                .group_by { |occ| occ.starts_at.to_date }
                                .transform_values { |occs| occs.map { |occ| agenda_entry_for(occ) } }

    @type_param = params[:type]

    all_entries = agenda_by_date.values.flatten.sort_by { |e| e[:time_sortable] }

    @pagy, page_entries = pagy(:offset, all_entries, limit: 10)

    @paged_agenda_by_date = page_entries.group_by { |entry| entry[:time_sortable].to_date }
  end

  private

  def agenda_entry_for(occ)
    item =
      if occ.respond_to?(:item)
        occ.item
      elsif occ.respond_to?(:event)
        occ.event
      elsif occ.respond_to?(:course)
        occ.course
      elsif occ.respond_to?(:color)
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
      color: occ.color
    }
  end
end
