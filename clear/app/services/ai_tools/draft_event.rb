module AiTools
  class DraftEvent
    def self.definition
      {
        name: "draft_event",
        description: "Create, update, or delete an existing event on the user's calendar draft. Use action=create to add events, action=update to change existing events, and action=delete to delete events.",
        parameters: {
          type: "OBJECT",
          properties: {
            action: { type: "STRING", description: "Mutation action: create, update, or delete" },
            event_id: { type: "INTEGER", description: "Preferred for action=update or action=delete. The ID of the event to change." },
            event_title: { type: "STRING", description: "Optional for action=update or action=delete when event_id is not available. Exact event title to target." },
            title: { type: "STRING", description: "Title of the event" },
            description: { type: "STRING", description: "Optional description or notes" },
            starts_at: { type: "STRING", description: "Start date/time in ISO 8601 format (e.g. 2026-03-20T14:00:00)" },
            ends_at: { type: "STRING", description: "Optional end date/time in ISO 8601 format" },
            duration_minutes: { type: "INTEGER", description: "Optional duration in minutes (used if ends_at is not provided)" },
            location: { type: "STRING", description: "Optional location" },
            color: { type: "STRING", description: "Optional hex color like #34D399" },
            recurring: { type: "BOOLEAN", description: "Whether the event repeats weekly" },
            repeat_days: { type: "ARRAY", items: { type: "STRING" }, description: "Weekdays using names or MTWRFSU codes, e.g. [\"M\", \"W\", \"F\"]" },
            meeting_days: { type: "STRING", description: "Weekday shorthand using MTWRFSU (R=Thu, U=Sun), e.g. MWF or TR" },
            repeat_until: { type: "STRING", description: "Required for recurring events. Last recurrence date in YYYY-MM-DD format." }
          },
          required: [ "action" ]
        }
      }
    end

    def self.call(user:, args:)
      action = args["action"].to_s.downcase

      case action
      when "create"
        create_event(user, args)
      when "update", "edit"
        update_event(user, args)
      when "delete", "remove"
        delete_event(user, args)
      else
        { success: false, errors: [ "Unsupported draft_event action: #{action.presence || 'blank'}" ] }
      end
    end

    def self.create_event(user, args)
      clarify = clarify_time(args["starts_at"], "starts_at") || clarify_time(args["ends_at"], "ends_at")
      return clarify if clarify

      event_attrs = {
        title: args["title"],
        description: args["description"],
        starts_at: parse_time(args["starts_at"]),
        ends_at: args["ends_at"].present? ? parse_time(args["ends_at"]) : nil,
        duration_minutes: args["duration_minutes"],
        location: args["location"],
        color: args["color"],
        recurring: parse_boolean(args["recurring"]),
        repeat_until: args["repeat_until"].present? ? parse_date(args["repeat_until"]) : nil
      }.compact
      repeat_days = normalize_repeat_days(args["repeat_days"], args["meeting_days"])
      event_attrs[:repeat_days] = repeat_days if repeat_days.any?
      event_attrs[:recurring] = true if event_attrs[:recurring].nil? && repeat_days.any?
      missing_fields = missing_create_fields(event_attrs)
      return required_fields_clarification_response(missing_fields) if missing_fields.any?

      draft = user.calendar_draft || user.create_calendar_draft!
      temp_id = draft.add_create("event", event_attrs)
      success_response(action: "create", event_id: temp_id, title: event_attrs[:title], starts_at: event_attrs[:starts_at])
    rescue => e
      { success: false, errors: [ e.message ] }
    end
    private_class_method :create_event

    def self.update_event(user, args)
      event = resolve_event(user, args)
      return event if event.is_a?(Hash) && event[:success] == false

      clarify = clarify_time(args["starts_at"], "starts_at") || clarify_time(args["ends_at"], "ends_at")
      return clarify if clarify

      updates = {}
      updates[:title] = args["title"] if args["title"].present?
      updates[:description] = args["description"] if args.key?("description")
      updates[:starts_at] = parse_time(args["starts_at"]) if args["starts_at"].present?
      updates[:ends_at] = parse_time(args["ends_at"]) if args["ends_at"].present?
      updates[:duration_minutes] = args["duration_minutes"] if args["duration_minutes"].present?
      updates[:location] = args["location"] if args.key?("location")
      updates[:color] = args["color"] if args["color"].present?
      updates[:recurring] = parse_boolean(args["recurring"]) if args.key?("recurring")
      updates[:repeat_until] = args["repeat_until"].present? ? parse_date(args["repeat_until"]) : nil if args.key?("repeat_until")
      updates[:repeat_days] = normalize_repeat_days(args["repeat_days"], args["meeting_days"]) if args.key?("repeat_days") || args["meeting_days"].present?

      if recurring_needs_days_or_until?(event, updates)
        return {
          success: false,
          needs_clarification: true,
          errors: [ "Recurring events require repeat_days and repeat_until." ],
          question: "For recurring events, please provide repeat_days and repeat_until (weekday names or MTWRFSU codes; R=Thu, U=Sun)."
        }
      end

      draft = user.calendar_draft || user.create_calendar_draft!
      draft.add_update("event", event.id, updates)

      starts_at = updates[:starts_at] || event.starts_at
      title = updates.key?(:title) ? updates[:title] : event.title
      success_response(action: "update", event_id: event.id, title: title, starts_at: starts_at)
    rescue => e
      { success: false, errors: [ e.message ] }
    end
    private_class_method :update_event

    def self.delete_event(user, args)
      event = resolve_event(user, args)
      return event if event.is_a?(Hash) && event[:success] == false

      draft = user.calendar_draft || user.create_calendar_draft!
      draft.add_delete("event", event.id)
      success_response(action: "delete", event_id: event.id, title: event.title, starts_at: event.starts_at)
    rescue => e
      { success: false, errors: [ e.message ] }
    end
    private_class_method :delete_event

    def self.parse_time(value)
      Time.zone.parse(value.to_s)
    end
    private_class_method :parse_time

    def self.parse_date(value)
      Date.parse(value.to_s)
    end
    private_class_method :parse_date

    def self.parse_boolean(value)
      return value if value == true || value == false

      text = value.to_s.strip.downcase
      return true if %w[true yes y 1].include?(text)
      return false if %w[false no n 0].include?(text)

      nil
    end
    private_class_method :parse_boolean

    def self.resolve_event(user, args)
      if args["event_id"].present?
        by_id = user.events.find_by(id: args["event_id"])
        return by_id if by_id
      end

      title = args["event_title"].presence || args["title"].presence
      return { success: false, errors: [ "Event not found" ] } if title.blank?

      matches = user.events
        .where("LOWER(title) = ?", title.to_s.strip.downcase)
        .order(starts_at: :asc)
        .limit(6)
        .to_a

      return matches.first if matches.one?
      return { success: false, errors: [ "Event not found" ] } if matches.empty?

      sample = matches.first(3).map { |e| "[ID:#{e.id}] #{e.title} at #{e.starts_at&.strftime('%b %-d %l:%M%P')}" }.join("; ")
      {
        success: false,
        needs_clarification: true,
        errors: [ "Multiple events matched '#{title}'." ],
        question: "I found multiple events named '#{title}'. Please provide the event ID. Matches: #{sample}."
      }
    end
    private_class_method :resolve_event

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

    def self.success_response(action:, event_id:, title:, starts_at:)
      {
        success: true,
        action: action,
        event_id: event_id,
        title: title,
        starts_at: starts_at&.iso8601
      }
    end
    private_class_method :success_response

    def self.missing_create_fields(event_attrs)
      missing = []
      missing << "title" if event_attrs[:title].blank?
      missing << "starts_at" if event_attrs[:starts_at].blank?
      if event_attrs[:recurring]
        missing << "repeat_days" if Array(event_attrs[:repeat_days]).reject(&:blank?).blank?
        missing << "repeat_until" if event_attrs[:repeat_until].blank?
      end
      missing
    end
    private_class_method :missing_create_fields

    def self.recurring_needs_days_or_until?(event, updates)
      recurring = updates.key?(:recurring) ? updates[:recurring] : event.recurring
      return false unless recurring

      desired_repeat_days = updates.key?(:repeat_days) ? updates[:repeat_days] : event.repeat_days
      desired_repeat_until = updates.key?(:repeat_until) ? updates[:repeat_until] : event.repeat_until
      Array(desired_repeat_days).reject(&:blank?).blank? || desired_repeat_until.blank?
    end
    private_class_method :recurring_needs_days_or_until?

    def self.required_fields_clarification_response(missing_fields)
      {
        success: false,
        needs_clarification: true,
        errors: [ "Missing required fields for event creation: #{missing_fields.join(', ')}" ],
        question: "Please provide #{missing_fields.join(', ')}. Events require title and starts_at. If recurring, include repeat_days and repeat_until (weekday names or MTWRFSU codes; R=Thu, U=Sun)."
      }
    end
    private_class_method :required_fields_clarification_response

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
