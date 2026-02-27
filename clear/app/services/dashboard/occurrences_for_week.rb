# frozen_string_literal: true

module Dashboard
  class OccurrencesForWeek
    def self.call(user:, start_date:, draft: nil)
      new(user: user, start_date: start_date, draft: draft).call
    end

    def initialize(user:, start_date:, draft:)
      @user = user
      @start_date = start_date.to_date
      @draft = draft
    end

    def call
      week_start  = @start_date.beginning_of_week
      range_start = week_start.beginning_of_day
      range_end   = (week_start + 6.days).end_of_day

      occurrences = base_occurrences(range_start, range_end)

      return occurrences unless @draft&.open?

      apply_draft_overlay(
        occurrences: occurrences,
        range_start: range_start,
        range_end: range_end
      )
    end

    private

    def base_occurrences(range_start, range_end)
      base_events =
        @user.events
             .where("starts_at <= ?", range_end)
             .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
             .order(starts_at: :asc)

      event_occurrences =
        base_events.flat_map { |e| e.occurrences_between(range_start, range_end) }

      base_courses =
        @user.courses
             .where("start_date <= ?", range_end.to_date)
             .where("end_date >= ?", range_start.to_date)
             .order(start_date: :asc)

      course_occurrences =
        base_courses.flat_map { |c| c.occurrences_between(range_start, range_end) }

      course_items =
        CourseItem
          .joins(:course)
          .where(courses: { user_id: @user.id })
          .where(due_at: range_start..range_end)
          .includes(:course)
          .to_a

      (event_occurrences + course_occurrences + course_items).sort_by(&:starts_at)
    end

    def apply_draft_overlay(occurrences:, range_start:, range_end:)
      ops =
        @draft.operations
              .where(status: %i[pending accepted])
              .order(:position, :id)

      # Split: CourseItem are real AR rows, others include Event occurrences
      course_items = occurrences.select { |o| o.is_a?(CourseItem) }
      other        = occurrences - course_items

      course_items_by_id   = course_items.index_by(&:id)
      created_course_items = []

      event_occurrences = other.select { |o| o.respond_to?(:event_id) || o.respond_to?(:base_event_id) }
      remaining_other   = other - event_occurrences

      event_occs_by_event_id =
        event_occurrences.group_by do |o|
          o.respond_to?(:event_id) ? o.event_id : o.base_event_id
        end

      created_events = []

      ops.each do |op|
        patch = (op.payload["patch"] || {}).to_h

        case op.target_type
        when "CourseItem"
          case op.op_type.to_sym
          when :add
            item = CourseItem.new(patch)
            mark_draft(item, op)
            created_course_items << item if in_range?(item, range_start, range_end)
          when :change
            item = course_items_by_id[op.target_id]
            next unless item

            patch.each { |k, v| item.public_send("#{k}=", v) if item.respond_to?("#{k}=") }
            mark_draft(item, op)
          when :remove
            removed = course_items_by_id.delete(op.target_id)
            mark_draft(removed, op) if removed
          end

        when "Event"
          case op.op_type.to_sym
          when :add
            e = Event.new(patch.merge(user_id: @user.id))
            mark_draft(e, op)
            created_events << e if in_range?(e, range_start, range_end)

          when :change
            occs = event_occs_by_event_id[op.target_id]
            next unless occs

            occs.each do |occ|
              base = occ.respond_to?(:event) ? occ.event : nil

              patch.each do |k, v|
                setter = "#{k}="

                # 1) Positioning is based on occ.starts_at / occ.ends_at
                occ.public_send(setter, v) if occ.respond_to?(setter)

                # 2) Display fields in your view come from `record = occ.event`
                base.public_send(setter, v) if base&.respond_to?(setter)
              end

              mark_draft(occ, op)
              mark_draft(base, op) if base
            end

          when :remove
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
end
