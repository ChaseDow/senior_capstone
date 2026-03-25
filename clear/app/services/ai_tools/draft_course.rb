module AiTools
  class DraftCourse
    def self.definition
      {
        name: "draft_course",
        description: "Create, update, or delete an existing course on the user's calendar draft. Use action=create to add courses, action=update to change existing courses, and action=delete to delete courses.",
        parameters: {
          type: "OBJECT",
          properties: {
            action: { type: "STRING", description: "Mutation action: create, update, or delete" },
            course_id: { type: "INTEGER", description: "Required for action=update or action=delete. The ID of the course to change." },
            title: { type: "STRING", description: "Title of the course" },
            term: { type: "STRING", description: "Optional academic term (e.g. Spring 2026)" },
            color: { type: "STRING", description: "Optional hex color like #34D399" },
            start_date: { type: "STRING", description: "Course start date in YYYY-MM-DD format" },
            end_date: { type: "STRING", description: "Course end date in YYYY-MM-DD format" },
            start_time: { type: "STRING", description: "Class start time in ISO 8601 or HH:MM format" },
            end_time: { type: "STRING", description: "Optional class end time in ISO 8601 or HH:MM format" },
            duration_minutes: { type: "INTEGER", description: "Optional duration in minutes (used if end_time is not provided)" },
            professor: { type: "STRING", description: "Optional professor name" },
            location: { type: "STRING", description: "Optional location" },
            description: { type: "STRING", description: "Optional description or notes" },
            repeat_days: { type: "ARRAY", items: { type: "STRING" }, description: "Optional weekdays using names or MTWRFSU codes, e.g. [\"M\", \"W\", \"F\"]" },
            meeting_days: { type: "STRING", description: "Optional weekday shorthand using MTWRFSU (R=Thu, U=Sun), e.g. MWF or TR" }
          },
          required: [ "action" ]
        }
      }
    end

    def self.call(user:, args:)
      action = args["action"].to_s.downcase

      case action
      when "create"
        create_course(user, args)
      when "update", "edit"
        update_course(user, args)
      when "delete", "remove"
        delete_course(user, args)
      else
        { success: false, errors: [ "Unsupported draft_course action: #{action.presence || 'blank'}" ] }
      end
    end

    def self.create_course(user, args)
      clarify = clarify_time(args["start_time"], "start_time") || clarify_time(args["end_time"], "end_time")
      return clarify if clarify

      course_attrs = build_course_attrs(args).compact
      missing_fields = missing_create_fields(course_attrs)
      return required_fields_clarification_response(missing_fields) if missing_fields.any?
      invalid = invalid_course_create_response(user, course_attrs)
      return invalid if invalid

      draft = user.calendar_draft || user.create_calendar_draft!
      temp_id = draft.add_create("course", course_attrs)
      success_response(action: "create", course_id: temp_id, title: course_attrs[:title], start_date: course_attrs[:start_date])
    rescue => e
      { success: false, errors: [ e.message ] }
    end
    private_class_method :create_course

    def self.update_course(user, args)
      course = user.courses.find_by(id: args["course_id"])
      return { success: false, errors: [ "Course not found" ] } unless course

      clarify = clarify_time(args["start_time"], "start_time") || clarify_time(args["end_time"], "end_time")
      return clarify if clarify

      updates = build_course_updates(args)
      invalid = invalid_course_update_response(user, course, updates)
      return invalid if invalid

      draft = user.calendar_draft || user.create_calendar_draft!
      draft.add_update("course", course.id, updates)

      title = updates.key?(:title) ? updates[:title] : course.title
      start_date = updates[:start_date] || course.start_date
      success_response(action: "update", course_id: course.id, title: title, start_date: start_date)
    rescue => e
      { success: false, errors: [ e.message ] }
    end
    private_class_method :update_course

    def self.delete_course(user, args)
      course = user.courses.find_by(id: args["course_id"])
      return { success: false, errors: [ "Course not found" ] } unless course

      draft = user.calendar_draft || user.create_calendar_draft!
      draft.add_delete("course", course.id)
      success_response(action: "delete", course_id: course.id, title: course.title, start_date: course.start_date)
    rescue => e
      { success: false, errors: [ e.message ] }
    end
    private_class_method :delete_course

    def self.build_course_updates(args)
      updates = {}
      updates[:title] = args["title"] if args["title"].present?
      updates[:term] = args["term"] if args["term"].present?
      updates[:color] = args["color"] if args["color"].present?
      updates[:start_date] = parse_date(args["start_date"]) if args["start_date"].present?
      updates[:end_date] = parse_date(args["end_date"]) if args["end_date"].present?
      updates[:start_time] = parse_time(args["start_time"]) if args["start_time"].present?
      updates[:end_time] = parse_time(args["end_time"]) if args["end_time"].present?
      updates[:duration_minutes] = args["duration_minutes"] if args["duration_minutes"].present?
      updates[:professor] = args["professor"] if args.key?("professor")
      updates[:location] = args["location"] if args.key?("location")
      updates[:description] = args["description"] if args.key?("description")
      updates[:repeat_days] = normalize_repeat_days(args["repeat_days"], args["meeting_days"]) if args.key?("repeat_days") || args["meeting_days"].present?
      updates
    end
    private_class_method :build_course_updates

    def self.build_course_attrs(args)
      attrs = build_course_updates(args)
      attrs[:repeat_days] = normalize_repeat_days(args["repeat_days"], args["meeting_days"]) unless attrs.key?(:repeat_days)
      attrs
    end
    private_class_method :build_course_attrs

    def self.normalize_repeat_days(repeat_days, meeting_days)
      from_array = parse_weekdays(Array(repeat_days))
      return from_array if from_array.any?
      return [] if meeting_days.blank?

      parse_weekdays([ meeting_days ])
    end
    private_class_method :normalize_repeat_days

    def self.parse_weekdays(values)
      map = {
        "m" => 1, "mon" => 1, "monday" => 1,
        "t" => 2, "tu" => 2, "tue" => 2, "tues" => 2, "tuesday" => 2,
        "w" => 3, "wed" => 3, "weds" => 3, "wednesday" => 3,
        "r" => 4, "th" => 4, "thu" => 4, "thur" => 4, "thurs" => 4, "thursday" => 4,
        "f" => 5, "fri" => 5, "friday" => 5,
        "s" => 6, "sa" => 6, "sat" => 6, "saturday" => 6,
        "u" => 0, "su" => 0, "sun" => 0, "sunday" => 0
      }

      out = []
      Array(values).each do |value|
        text = value.to_s.strip.downcase
        next if text.blank?

        if text.match?(/\A[mtwrfsu]+\z/)
          text.chars.each { |ch| out << map[ch] if map.key?(ch) }
          next
        end

        text.gsub(/[^a-z]+/, " ").split.each do |token|
          out << map[token] if map.key?(token)
        end
      end

      out.compact.uniq.sort
    end
    private_class_method :parse_weekdays

    def self.parse_date(value)
      Date.parse(value.to_s)
    end
    private_class_method :parse_date

    def self.parse_time(value)
      Time.zone.parse(value.to_s)
    end
    private_class_method :parse_time

    def self.success_response(action:, course_id:, title:, start_date:)
      {
        success: true,
        action: action,
        course_id: course_id,
        title: title,
        start_date: start_date&.to_s
      }
    end
    private_class_method :success_response

    def self.missing_create_fields(course_attrs)
      missing = []
      missing << "title" if course_attrs[:title].blank?
      missing << "start_date" if course_attrs[:start_date].blank?
      missing << "end_date" if course_attrs[:end_date].blank?
      missing << "start_time" if course_attrs[:start_time].blank?
      missing << "repeat_days" if Array(course_attrs[:repeat_days]).reject(&:blank?).blank?
      missing
    end
    private_class_method :missing_create_fields

    def self.required_fields_clarification_response(missing_fields)
      {
        success: false,
        needs_clarification: true,
        errors: [ "Missing required fields for course creation: #{missing_fields.join(', ')}" ],
        question: "Please provide #{missing_fields.join(', ')}. Courses require title, start date, end date, start time, and repeat days (weekday names or MTWRFSU codes; R=Thu, U=Sun)."
      }
    end
    private_class_method :required_fields_clarification_response

    def self.invalid_course_create_response(user, attrs)
      course = user.courses.new(attrs)
      return nil if course.valid?

      {
        success: false,
        needs_clarification: true,
        errors: course.errors.full_messages,
        question: "I still need a few details before drafting this course. #{course.errors.full_messages.first}"
      }
    end
    private_class_method :invalid_course_create_response

    def self.invalid_course_update_response(user, course, updates)
      attrs = course.attributes.except("id", "user_id", "created_at", "updated_at")
      candidate = user.courses.new(attrs.merge(updates.stringify_keys))
      return nil if candidate.valid?

      {
        success: false,
        needs_clarification: true,
        errors: candidate.errors.full_messages,
        question: "I still need a few details before drafting this update. #{candidate.errors.full_messages.first}"
      }
    end
    private_class_method :invalid_course_update_response

    def self.clarify_time(value, field)
      text = value.to_s.strip
      return nil if text.blank? || text.match?(/\b(?:am|pm|a\.?\s*m\.?|p\.?\s*m\.?)\b/i) || text.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/i)
      m = text.match(/(?:\A|[ T])(\d{1,2}):(\d{2})(?::\d{2})?(?:\b|$)/)
      return nil unless m && m[1].to_i.between?(1, 12)
      { success: false, needs_clarification: true, errors: [ "clarify_time: #{field}" ], question: "Clarify time: provide the full #{field} with AM/PM (for example, #{text} AM or #{text} PM)." }
    end
    private_class_method :clarify_time
  end
end
