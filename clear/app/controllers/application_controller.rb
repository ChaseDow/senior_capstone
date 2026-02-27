# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protected

  def after_sign_in_path_for(resource)
    authenticated_root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  private

  # -------------------------
  # Draft helpers (session-backed)
  # -------------------------

  def current_calendar_draft
    id = params[:draft_id].presence || session[:calendar_draft_id].presence
    return nil if id.blank?
    current_user.calendar_drafts.open.find_by(id: id)
  end
  helper_method :current_calendar_draft

  def set_active_draft!(draft)
    session[:calendar_draft_id] = draft.id
  end

  def clear_active_draft!
    session.delete(:calendar_draft_id)
  end

  # -------------------------
  # Dashboard occurrences builder (WITH optional draft overlay)
  # -------------------------

  def dashboard_week_occurrences_for(start_date, draft: current_calendar_draft)
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    base_events = current_user.events

    non_recurring_events =
      base_events
        .where(recurring: false)
        .where(starts_at: range_start..range_end)

    recurring_events =
      base_events
        .where(recurring: true)
        .where("starts_at <= ?", range_end)
        .where("repeat_until >= ?", range_start.to_date)

    event_occurrences =
      (non_recurring_events + recurring_events)
        .flat_map { |e| e.occurrences_between(range_start, range_end) }

    base_courses =
      current_user.courses
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
        .to_a

    occurrences =
      (event_occurrences + course_occurrences + course_items)
        .sort_by(&:starts_at)

    return occurrences unless draft&.open?

    apply_draft_overlay(
      user: current_user,
      draft: draft,
      occurrences: occurrences,
      range_start: range_start,
      range_end: range_end
    )
  end

  # -------------------------
  # Overlay engine
  # -------------------------

  def normalized_op_type(op)
    t = op.op_type.to_sym
    return :create if t == :add
    return :update if t == :change
    return :delete if t == :remove
    t
  end

  def apply_draft_overlay(user:, draft:, occurrences:, range_start:, range_end:)
    ops =
      draft.operations
           .where(status: %i[pending accepted])
           .order(:position, :id)

    course_items = occurrences.select { |o| o.is_a?(CourseItem) }
    other = occurrences - course_items

    course_items_by_id = course_items.index_by(&:id)
    created_course_items = []

    # Event occurrences are wrappers (respond_to? event_id/base_event_id) and the UI reads occ.event
    event_occurrences = other.select { |o| o.respond_to?(:event_id) || o.respond_to?(:base_event_id) }
    remaining_other = other - event_occurrences

    event_occs_by_event_id =
      event_occurrences.group_by do |o|
        o.respond_to?(:event_id) ? o.event_id : o.base_event_id
      end

    created_events = []

    ops.each do |op|
      patch = (op.payload["patch"] || {}).to_h

      case op.target_type
      when "CourseItem"
        case normalized_op_type(op)
        when :create
          item = CourseItem.new(patch)
          mark_draft(item, op)
          created_course_items << item if in_range?(item, range_start, range_end)
        when :update
          item = course_items_by_id[op.target_id]
          next unless item
          patch.each { |k, v| item.public_send("#{k}=", v) if item.respond_to?("#{k}=") }
          mark_draft(item, op)
        when :delete
          removed = course_items_by_id.delete(op.target_id)
          mark_draft(removed, op) if removed
        end

      when "Event"
        case normalized_op_type(op)
        when :create
          e = Event.new(patch.merge(user_id: user.id))
          mark_draft(e, op)
          created_events << e if in_range?(e, range_start, range_end)

        when :update
          occs = event_occs_by_event_id[op.target_id]
          next unless occs

          occs.each do |occ|
            base = occ.respond_to?(:event) ? occ.event : nil

            patch.each do |k, v|
              setter = "#{k}="

              # 1) Patch the wrapper for time/layout
              occ.public_send(setter, v) if occ.respond_to?(setter)

              # 2) Patch the base Event because your calendar UI reads from occ.event
              base.public_send(setter, v) if base&.respond_to?(setter)
            end

            mark_draft(occ, op)
            mark_draft(base, op) if base
          end

        when :delete
          event_occs_by_event_id.delete(op.target_id)
        end
      end
    end

    final =
      remaining_other +
      event_occs_by_event_id.values.flatten +
      course_items_by_id.values +
      created_course_items +
      created_events

    final.sort_by(&:starts_at)
  end

  def in_range?(obj, range_start, range_end)
    return false unless obj.respond_to?(:starts_at)
    return false if obj.starts_at.blank?
    obj.starts_at >= range_start && obj.starts_at <= range_end
  end

  def mark_draft(obj, op)
    return unless obj
    obj.define_singleton_method(:draft_meta) do
      { op_id: op.id, op_type: op.op_type, target_type: op.target_type }
    end
  end
end
