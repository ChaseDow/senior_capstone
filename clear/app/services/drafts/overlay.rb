# frozen_string_literal: true

module Drafts
  class Overlay
    def self.call(user:, draft:, occurrences:, range_start:, range_end:)
      new(user, draft, occurrences, range_start, range_end).call
    end

    def initialize(user, draft, occurrences, range_start, range_end)
      @user = user
      @draft = draft
      @occurrences = occurrences
      @range_start = range_start
      @range_end = range_end
    end

    def call
      ops =
        @draft.operations
              .where(status: %i[pending accepted])
              .order(:position, :id)

      course_items = @occurrences.select { |o| o.is_a?(CourseItem) }
      other = @occurrences - course_items

      course_items_by_id = course_items.index_by(&:id)
      created_course_items = []

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
          apply_course_item(op, patch, course_items_by_id, created_course_items)
        when "Event"
          apply_event(op, patch, event_occs_by_event_id, created_events)
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

    private

    def apply_course_item(op, patch, by_id, created)
      case op.op_type.to_sym
      when :add
        item = CourseItem.new(patch)
        mark_draft(item, op)
        created << item if in_range?(item)
      when :change
        item = by_id[op.target_id]
        return unless item
        patch.each { |k, v| item.public_send("#{k}=", v) if item.respond_to?("#{k}=") }
        mark_draft(item, op)
      when :remove
        removed = by_id.delete(op.target_id)
        mark_draft(removed, op) if removed
      end
    end

    def apply_event(op, patch, by_event_id, created_events)
      case op.op_type.to_sym
      when :add
        e = Event.new(patch.merge(user_id: @user.id))
        mark_draft(e, op)
        created_events << e if in_range?(e)
      when :change
        occs = by_event_id[op.target_id]
        return unless occs
        occs.each do |occ|
          patch.each do |k, v|
            setter = "#{k}="
            occ.public_send(setter, v) if occ.respond_to?(setter)
          end
          mark_draft(occ, op)
        end
      when :remove
        by_event_id.delete(op.target_id)
      end
    end

    def in_range?(obj)
      obj.respond_to?(:starts_at) &&
        obj.starts_at.present? &&
        obj.starts_at >= @range_start &&
        obj.starts_at <= @range_end
    end

    def mark_draft(obj, op)
      return unless obj
      obj.define_singleton_method(:draft_meta) do
        { op_id: op.id, op_type: op.op_type, target_type: op.target_type }
      end
    end
  end
end
