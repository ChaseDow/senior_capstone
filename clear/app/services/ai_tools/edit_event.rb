module AiTools
  class EditEvent
    def self.definition
      {
        name: "edit_event",
        description: "Edit an existing event on the user's calendar. Use this when the user asks to change, update, move, or reschedule an event. Only include fields that should be changed.",
        parameters: {
          type: "OBJECT",
          properties: {
            event_id: { type: "INTEGER", description: "The ID of the event to edit" },
            title: { type: "STRING", description: "New title" },
            description: { type: "STRING", description: "New description" },
            starts_at: { type: "STRING", description: "New start date/time in ISO 8601 format" },
            ends_at: { type: "STRING", description: "New end date/time in ISO 8601 format" },
            duration_minutes: { type: "INTEGER", description: "New duration in minutes" },
            location: { type: "STRING", description: "New location" },
            color: { type: "STRING", description: "New hex color like #34D399" }
          },
          required: [ "event_id" ]
        }
      }
    end

    def self.call(user:, args:)
      event = user.events.find_by(id: args["event_id"])
      return { success: false, errors: [ "Event not found" ] } unless event

      updates = build_updates(args)

      if event.update(updates)
        success_response(event)
      else
        { success: false, errors: event.errors.full_messages }
      end
    end

    def self.build_updates(args)
      updates = {}
      updates[:title] = args["title"] if args["title"].present?
      updates[:description] = args["description"] if args.key?("description")
      updates[:starts_at] = parse_time(args["starts_at"]) if args["starts_at"].present?
      updates[:ends_at] = parse_time(args["ends_at"]) if args["ends_at"].present?
      updates[:duration_minutes] = args["duration_minutes"] if args["duration_minutes"].present?
      updates[:location] = args["location"] if args.key?("location")
      updates[:color] = args["color"] if args["color"].present?
      updates
    end
    private_class_method :build_updates

    def self.parse_time(value)
      Time.zone.parse(value)
    end
    private_class_method :parse_time

    def self.success_response(event)
      {
        success: true,
        event_id: event.id,
        title: event.title,
        starts_at: event.starts_at.iso8601
      }
    end
    private_class_method :success_response
  end
end
