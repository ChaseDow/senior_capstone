module AiTools
  class MutateEvent
    def self.definition
      {
        name: "mutate_event",
        description: "Create or update an existing event on the user's calendar. Use action=create to add events and action=update to change existing events.",
        parameters: {
          type: "OBJECT",
          properties: {
            action: { type: "STRING", description: "Mutation action: create or update" },
            event_id: { type: "INTEGER", description: "Required for action=update. The ID of the event to change." },
            title: { type: "STRING", description: "Title of the event" },
            description: { type: "STRING", description: "Optional description or notes" },
            starts_at: { type: "STRING", description: "Start date/time in ISO 8601 format (e.g. 2026-03-20T14:00:00)" },
            ends_at: { type: "STRING", description: "Optional end date/time in ISO 8601 format" },
            duration_minutes: { type: "INTEGER", description: "Optional duration in minutes (used if ends_at is not provided)" },
            location: { type: "STRING", description: "Optional location" },
            color: { type: "STRING", description: "Optional hex color like #34D399" }
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
      else
        { success: false, errors: [ "Unsupported mutate_event action: #{action.presence || 'blank'}" ] }
      end
    end

    def self.create_event(user, args)
      event = user.events.new(
        title: args["title"],
        description: args["description"],
        starts_at: parse_time(args["starts_at"]),
        ends_at: args["ends_at"].present? ? parse_time(args["ends_at"]) : nil,
        duration_minutes: args["duration_minutes"],
        location: args["location"],
        color: args["color"]
      )

      if event.save
        success_response(event, "create")
      else
        { success: false, errors: event.errors.full_messages }
      end
    end
    private_class_method :create_event

    def self.update_event(user, args)
      event = user.events.find_by(id: args["event_id"])
      return { success: false, errors: [ "Event not found" ] } unless event

      updates = {}
      updates[:title] = args["title"] if args["title"].present?
      updates[:description] = args["description"] if args.key?("description")
      updates[:starts_at] = parse_time(args["starts_at"]) if args["starts_at"].present?
      updates[:ends_at] = parse_time(args["ends_at"]) if args["ends_at"].present?
      updates[:duration_minutes] = args["duration_minutes"] if args["duration_minutes"].present?
      updates[:location] = args["location"] if args.key?("location")
      updates[:color] = args["color"] if args["color"].present?

      if event.update(updates)
        success_response(event, "update")
      else
        { success: false, errors: event.errors.full_messages }
      end
    end
    private_class_method :update_event

    def self.parse_time(value)
      Time.zone.parse(value)
    end
    private_class_method :parse_time

    def self.success_response(event, action)
      {
        success: true,
        action: action,
        event_id: event.id,
        title: event.title,
        starts_at: event.starts_at.iso8601
      }
    end
    private_class_method :success_response
  end
end
