module AiTools
  class CreateEvent
    def self.definition
      {
        name: "create_event",
        description: "Create a new event on the user's calendar. Use this when the user asks to add, schedule, or create an event.",
        parameters: {
          type: "OBJECT",
          properties: {
            title: { type: "STRING", description: "Title of the event" },
            description: { type: "STRING", description: "Optional description or notes" },
            starts_at: { type: "STRING", description: "Start date/time in ISO 8601 format (e.g. 2026-03-20T14:00:00)" },
            ends_at: { type: "STRING", description: "Optional end date/time in ISO 8601 format" },
            duration_minutes: { type: "INTEGER", description: "Optional duration in minutes (used if ends_at is not provided)" },
            location: { type: "STRING", description: "Optional location" },
            color: { type: "STRING", description: "Optional hex color like #34D399" }
          },
          required: [ "title", "starts_at" ]
        }
      }
    end

    def self.call(user:, args:)
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
        success_response(event)
      else
        { success: false, errors: event.errors.full_messages }
      end
    end

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
