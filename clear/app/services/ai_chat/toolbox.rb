# frozen_string_literal: true

require "json"

module AiChat
  class Toolbox
    TOOL_NAME = "draft_reschedule_event_time"

    class << self
      def system_prompt
        <<~PROMPT
          You can call one function tool when needed.

          Tool name: #{TOOL_NAME}
          Purpose: Queue an event time change in the calendar draft system.

          Required arguments:
          - starts_at (string): new start date/time, e.g. "2026-03-21 14:00"

          Event identifier (provide one):
          - event_id (integer), or
          - event_title (string)

          Optional arguments:
          - ends_at (string): explicit end date/time
          - duration_minutes (integer): use this to compute end time

          If the user asks to change/reschedule/move event time, respond ONLY with JSON:
          {"tool":"#{TOOL_NAME}","args":{...}}

          If no tool is needed, answer normally.
        PROMPT
      end

      def run_if_requested(raw_reply:, user:, session:)
        call = parse_tool_call(raw_reply)
        return raw_reply unless call

        args = call["args"]
        return "Tool call format is invalid. Please provide valid JSON arguments for the time change." unless args.is_a?(Hash)

        execute_reschedule_tool(args: args, user: user, session: session)
      rescue => e
        "I could not draft that time change: #{e.message}"
      end

      private

      def parse_tool_call(raw_reply)
        payload = extract_json_payload(raw_reply.to_s)
        return nil unless payload.is_a?(Hash)
        return nil unless payload["tool"] == TOOL_NAME

        payload
      end

      def extract_json_payload(text)
        stripped = text.strip
        JSON.parse(stripped)
      rescue JSON::ParserError
        if stripped.start_with?("```")
          without_fences = stripped.gsub(/\A```[a-zA-Z]*\s*/, "").gsub(/\s*```\z/, "")
          return JSON.parse(without_fences)
        end

        start_idx = stripped.index("{")
        end_idx = stripped.rindex("}")
        return nil unless start_idx && end_idx && end_idx > start_idx

        JSON.parse(stripped[start_idx..end_idx])
      rescue JSON::ParserError
        nil
      end

      def execute_reschedule_tool(args:, user:, session:)
        event = find_event(user: user, args: args)
        raise "Event not found." unless event

        new_start = parse_time!(
          args["starts_at"],
          field_name: "starts_at",
          default_date: event.starts_at&.to_date,
          default_time_from: event.starts_at
        )
        new_end = resolve_end_time(args: args, event: event, new_start: new_start)

        draft = CalendarDraft.find_or_create_by!(user: user)
        session[:calendar_draft_mode] = true

        update_payload = { "starts_at" => new_start.iso8601 }
        update_payload["ends_at"] = new_end.iso8601 if new_end
        draft.add_update("event", event.id, update_payload)

        range = if new_end
          "#{new_start.strftime("%b %-d, %Y %-I:%M%P")} - #{new_end.strftime("%-I:%M%P")}"
        else
          new_start.strftime("%b %-d, %Y %-I:%M%P")
        end

        "Draft updated: \"#{event.title}\" is now set to #{range}. Review it in Dashboard and click Apply Draft to save."
      end

      def find_event(user:, args:)
        if args["event_id"].present?
          return user.events.find_by(id: args["event_id"].to_i)
        end

        title = args["event_title"].to_s.strip
        return nil if title.blank?

        user.events.where("title ILIKE ?", "%#{title}%").order(:starts_at).first
      end

      def resolve_end_time(args:, event:, new_start:)
        if args["ends_at"].present?
          new_end = parse_time!(
            args["ends_at"],
            field_name: "ends_at",
            default_date: new_start.to_date,
            default_time_from: event.ends_at
          )
          raise "ends_at must be after starts_at." if new_end <= new_start
          return new_end
        end

        if args["duration_minutes"].present?
          minutes = args["duration_minutes"].to_i
          raise "duration_minutes must be greater than 0." if minutes <= 0
          return new_start + minutes.minutes
        end

        if event.starts_at.present? && event.ends_at.present?
          duration_seconds = event.ends_at - event.starts_at
          return new_start + duration_seconds if duration_seconds.positive?
        end

        nil
      end

      def parse_time!(value, field_name:, default_date:, default_time_from: nil)
        raise "#{field_name} is required." if value.blank?

        raw = normalize_temporal_phrase(value)
        raw_date = relative_date_keyword(raw)

        parsed = if time_only_input?(raw) && default_date.present?
          parsed_time = Time.zone.parse(raw)
          if parsed_time
            Time.zone.local(
              default_date.year, default_date.month, default_date.day,
              parsed_time.hour, parsed_time.min, parsed_time.sec
            )
          end
        elsif raw_date && default_time_from.present?
          source = default_time_from.in_time_zone
          Time.zone.local(raw_date.year, raw_date.month, raw_date.day, source.hour, source.min, source.sec)
        elsif raw_date
          Time.zone.local(raw_date.year, raw_date.month, raw_date.day, 0, 0, 0)
        elsif date_only_input?(raw) && default_time_from.present?
          date = Date.parse(raw) rescue nil
          if date
            source = default_time_from.in_time_zone
            Time.zone.local(date.year, date.month, date.day, source.hour, source.min, source.sec)
          end
        else
          Time.zone.parse(raw)
        end

        raise "#{field_name} must be a valid date/time." if parsed.nil?

        parsed
      end

      def time_only_input?(raw)
        raw.match?(/\A\s*(\d{1,2})(:\d{2})?\s*(am|pm)?\s*\z/i)
      end

      def date_only_input?(raw)
        raw.match?(/\A\s*\d{1,4}[\/\-]\d{1,2}[\/\-]\d{1,4}\s*\z/)
      end

      def relative_date_keyword(raw)
        case raw.to_s.downcase.strip
        when "today" then Date.current
        when "tomorrow" then Date.current + 1.day
        when "yesterday" then Date.current - 1.day
        end
      end

      def normalize_temporal_phrase(value)
        value.to_s
          .gsub(/[?!]+/, " ")
          .gsub(/\b(with\s+the\s+same\s+date|on\s+the\s+same\s+date|same\s+date|same\s+day)\b/i, "")
          .gsub(/\b(currently|right now)\b.*$/i, "")
          .gsub(/[,\s]+/, " ")
          .strip
      end
    end
  end
end
