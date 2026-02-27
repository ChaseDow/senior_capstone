# frozen_string_literal: true

module CalendarDrafts
  class Apply
    def self.call!(draft:)
      new(draft: draft).call!
    end

    def initialize(draft:)
      @draft = draft
      @user  = draft.user
    end

    def call!
      raise ArgumentError, "draft must be open" unless @draft.open?

      ActiveRecord::Base.transaction do
        ops =
          @draft.operations
                .where(status: %i[pending accepted])
                .order(:position, :id)

        ops.each { |op| apply_op!(op) }

        # Optional: mark ops "accepted" after applying (never sets nil)
        if CalendarDraftOperation.respond_to?(:statuses) && CalendarDraftOperation.statuses.key?("accepted")
          @draft.operations.where(id: ops.map(&:id)).update_all(
            status: CalendarDraftOperation.statuses["accepted"],
            updated_at: Time.current
          )
        end
      end
    end

    private

    # Support either naming scheme:
    # - :create/:update/:delete
    # - :add/:change/:remove
    def normalized_op_type(op)
      t = op.op_type.to_sym
      return :create if t == :add
      return :update if t == :change
      return :delete if t == :remove
      t
    end

    def apply_op!(op)
      patch = (op.payload["patch"] || {}).to_h
      kind  = normalized_op_type(op)

      case op.target_type
      when "Event"
        apply_event_op!(op, patch, kind)
      when "CourseItem"
        apply_course_item_op!(op, patch, kind)
      end
    end

    def apply_event_op!(op, patch, kind)
      case kind
      when :create
        @user.events.create!(patch)

      when :update
        event = @user.events.find_by(id: op.target_id)
        return unless event
        event.update!(patch)

      when :delete
        event = @user.events.find_by(id: op.target_id)
        return unless event
        event.destroy!
      end
    end

    def apply_course_item_op!(op, patch, kind)
      case kind
      when :create
        course_id = patch["course_id"] || patch[:course_id]
        raise ActiveRecord::RecordNotFound, "course_id missing" if course_id.blank?

        course = @user.courses.find(course_id)
        attrs  = patch.except("course_id", :course_id)
        course.course_items.create!(attrs)

      when :update
        item =
          CourseItem.joins(:course)
                    .where(courses: { user_id: @user.id })
                    .find_by(id: op.target_id)
        return unless item
        item.update!(patch)

      when :delete
        item =
          CourseItem.joins(:course)
                    .where(courses: { user_id: @user.id })
                    .find_by(id: op.target_id)
        return unless item
        item.destroy!
      end
    end
  end
end
