module AiTools
  class DraftCourseItem
    ALLOWED_KINDS = %w[assignment quiz exam project reading lab presentation seminar other].freeze

    def self.definition
      {
        name: "draft_course_item",
        description: "Create, update, or delete an existing course item on the user's calendar draft. Use action=create to add items, action=update to change existing items, and action=delete to delete items.",
        parameters: {
          type: "OBJECT",
          properties: {
            action: { type: "STRING", description: "Mutation action: create, update, or delete" },
            course_item_id: { type: "INTEGER", description: "Preferred for action=update or action=delete. The ID of the course item to change." },
            course_item_title: { type: "STRING", description: "Preferred for action=update or action=delete when course_item_id is not available. Item title or display title to target." },
            course_id: { type: "INTEGER", description: "Required for action=create. The course ID this item belongs to." },
            title: { type: "STRING", description: "Course item title" },
            kind: { type: "STRING", description: "assignment, quiz, exam, project, reading, lab, presentation, seminar, or other" },
            due_at: { type: "STRING", description: "Required for create. Must include date and time (e.g. 2026-04-10T14:00:00)." },
            details: { type: "STRING", description: "Optional details/notes" }
          },
          required: [ "action" ]
        }
      }
    end

    def self.call(user:, args:)
      action = args["action"].to_s.downcase

      case action
      when "create"
        create_course_item(user, args)
      when "update", "edit"
        update_course_item(user, args)
      when "delete", "remove"
        delete_course_item(user, args)
      else
        { success: false, errors: [ "Unsupported draft_course_item action: #{action.presence || 'blank'}" ] }
      end
    end

    def self.create_course_item(user, args)
      due_clarification = due_at_clarification(args["due_at"]) if args["due_at"].present?
      return due_clarification if due_clarification

      item_attrs = {
        course_id: args["course_id"],
        title: args["title"],
        kind: normalize_kind(args["kind"]),
        due_at: args["due_at"].present? ? parse_time(args["due_at"]) : nil,
        details: args["details"]
      }.compact

      missing_fields = missing_create_fields(item_attrs)
      return required_fields_clarification_response(missing_fields) if missing_fields.any?

      course = user.courses.find_by(id: item_attrs[:course_id])
      return invalid_course_clarification_response unless course

      invalid = invalid_item_create_response(course, item_attrs)
      return invalid if invalid

      draft = user.calendar_draft || user.create_calendar_draft!
      temp_id = draft.add_create("course_item", item_attrs)
      success_response(action: "create", course_item_id: temp_id, title: item_attrs[:title], due_at: item_attrs[:due_at])
    rescue => e
      { success: false, errors: [ e.message ] }
    end
    private_class_method :create_course_item

    def self.update_course_item(user, args)
      item = resolve_course_item(user, args)
      return item if item.is_a?(Hash) && item[:success] == false

      due_clarification = due_at_clarification(args["due_at"]) if args["due_at"].present?
      return due_clarification if due_clarification

      updates = {}
      updates[:course_id] = args["course_id"] if args["course_id"].present?
      updates[:title] = args["title"] if args["title"].present?
      updates[:kind] = normalize_kind(args["kind"]) if args["kind"].present?
      updates[:due_at] = parse_time(args["due_at"]) if args["due_at"].present?
      updates[:details] = args["details"] if args.key?("details")

      if updates[:course_id].present? && !user.courses.exists?(id: updates[:course_id])
        return invalid_course_clarification_response
      end

      invalid = invalid_item_update_response(user, item, updates)
      return invalid if invalid

      draft = user.calendar_draft || user.create_calendar_draft!
      draft.add_update("course_item", item.id, updates)

      title = updates.key?(:title) ? updates[:title] : item.title
      due_at = updates[:due_at] || item.due_at
      success_response(action: "update", course_item_id: item.id, title: title, due_at: due_at)
    rescue => e
      { success: false, errors: [ e.message ] }
    end
    private_class_method :update_course_item

    def self.delete_course_item(user, args)
      item = resolve_course_item(user, args)
      return item if item.is_a?(Hash) && item[:success] == false

      draft = user.calendar_draft || user.create_calendar_draft!
      draft.add_delete("course_item", item.id)
      success_response(action: "delete", course_item_id: item.id, title: item.title, due_at: item.due_at)
    rescue => e
      { success: false, errors: [ e.message ] }
    end
    private_class_method :delete_course_item

    def self.resolve_course_item(user, args)
      scope = CourseItem.joins(:course).where(courses: { user_id: user.id })
      scope = scope.where(course_id: args["course_id"]) if args["course_id"].present?

      if args["course_item_id"].present?
        by_id = scope.find_by(id: args["course_item_id"])
        return by_id if by_id
      end

      title = args["course_item_title"].presence || args["title"].presence
      return { success: false, errors: [ "Course item not found" ] } if title.blank?
      normalized_title = normalize_lookup_text(title)

      matches = scope
        .where("LOWER(course_items.title) = ?", title.to_s.strip.downcase)
        .order(due_at: :asc)
        .limit(6)
        .to_a

      if matches.empty?
        matches = scope
          .includes(:course)
          .order(due_at: :asc)
          .limit(200)
          .to_a
          .select { |ci| lookup_matches?(ci, normalized_title) }
          .first(6)
      end

      return matches.first if matches.one?
      return { success: false, errors: [ "Course item not found" ] } if matches.empty?

      sample = matches.first(3).map { |ci| "[ID:#{ci.id}] #{ci.title}#{ci.due_at ? " due #{ci.due_at.strftime('%b %-d %l:%M%P')}" : ''}" }.join("; ")
      {
        success: false,
        needs_clarification: true,
        errors: [ "Multiple course items matched '#{title}'." ],
        question: "I found multiple course items named '#{title}'. Please provide the course item ID. Matches: #{sample}."
      }
    end
    private_class_method :resolve_course_item

    def self.lookup_matches?(item, normalized_title)
      candidates = [
        item.title,
        item.display_title,
        "#{item.course&.title} #{item.title}",
        "#{item.kind&.humanize}: #{item.title}"
      ].compact

      candidates.any? { |text| normalize_lookup_text(text) == normalized_title }
    end
    private_class_method :lookup_matches?

    def self.normalize_lookup_text(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squeeze(" ").strip
    end
    private_class_method :normalize_lookup_text

    def self.parse_time(value)
      Time.zone.parse(value.to_s)
    end
    private_class_method :parse_time

    def self.normalize_kind(value)
      kind = value.to_s.strip.downcase
      return nil if kind.blank?

      ALLOWED_KINDS.include?(kind) ? kind : "other"
    end
    private_class_method :normalize_kind

    def self.due_at_clarification(value)
      text = value.to_s.strip
      has_date = text.match?(/\d{4}-\d{1,2}-\d{1,2}|\d{1,2}\/\d{1,2}(?:\/\d{2,4})?|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)/i)
      has_time = text.match?(/\b\d{1,2}:\d{2}(?:\s?(?:am|pm))?\b|\b\d{1,2}\s?(?:am|pm)\b/i)
      return nil if has_date && has_time

      {
        success: false,
        needs_clarification: true,
        errors: [ "due_at must include both date and time" ],
        question: "Please provide due_at with both a date and a time (for example, 2026-04-10 2:00 PM)."
      }
    end
    private_class_method :due_at_clarification

    def self.missing_create_fields(item_attrs)
      missing = []
      missing << "course_id" if item_attrs[:course_id].blank?
      missing << "title" if item_attrs[:title].blank?
      missing << "kind" if item_attrs[:kind].blank?
      missing << "due_at" if item_attrs[:due_at].blank?
      missing
    end
    private_class_method :missing_create_fields

    def self.required_fields_clarification_response(missing_fields)
      {
        success: false,
        needs_clarification: true,
        errors: [ "Missing required fields for course item creation: #{missing_fields.join(', ')}" ],
        question: "Course items must belong to a course. Please provide #{missing_fields.join(', ')}."
      }
    end
    private_class_method :required_fields_clarification_response

    def self.invalid_course_clarification_response
      {
        success: false,
        needs_clarification: true,
        errors: [ "Course not found" ],
        question: "Course items must belong to a valid course. Please provide a valid course_id."
      }
    end
    private_class_method :invalid_course_clarification_response

    def self.invalid_item_create_response(course, attrs)
      candidate = course.course_items.new(attrs.except(:course_id))
      return nil if candidate.valid?

      {
        success: false,
        needs_clarification: true,
        errors: candidate.errors.full_messages,
        question: "I still need a few details before drafting this course item. #{candidate.errors.full_messages.first}"
      }
    end
    private_class_method :invalid_item_create_response

    def self.invalid_item_update_response(user, item, updates)
      course_id = updates[:course_id] || item.course_id
      course = user.courses.find_by(id: course_id)
      return invalid_course_clarification_response unless course

      attrs = item.attributes.except("id", "created_at", "updated_at")
      candidate = course.course_items.new(attrs.merge(updates.stringify_keys).except("course_id"))
      return nil if candidate.valid?

      {
        success: false,
        needs_clarification: true,
        errors: candidate.errors.full_messages,
        question: "I still need a few details before drafting this update. #{candidate.errors.full_messages.first}"
      }
    end
    private_class_method :invalid_item_update_response

    def self.success_response(action:, course_item_id:, title:, due_at:)
      {
        success: true,
        action: action,
        course_item_id: course_item_id,
        title: title,
        due_at: due_at&.iso8601
      }
    end
    private_class_method :success_response
  end
end
