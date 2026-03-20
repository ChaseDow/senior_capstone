# frozen_string_literal: true

require "ruby_llm"

module AiChat
  module Tooling
    class MutateEventTool < RubyLLM::Tool
      TOOL_NAME = "mutate_event"

      description "Create, update, or delete event drafts."
      param :action
      param :id
      param :event_id
      param :title
      param :event_title
      param :target_title
      param :from_title
      param :new_title
      param :rename_to
      param :attributes
      param :operations

      def execute(**args)
        context = CalendarMutationTool.current_context
        CalendarMutationTool.call(
          args: normalize_args(args),
          user: context.fetch(:user),
          session: context.fetch(:session)
        )
      rescue KeyError
        "I couldn't complete that change right now. Please try again."
      rescue CalendarMutationTool::UserFacingError => e
        e.message
      rescue => e
        Rails.logger.error("MutateEventTool error: #{e.class}: #{e.message}")
        "I couldn't complete that event change right now. Please try again with the event title, date, and time."
      end

      class << self
        def prompt_instructions
          <<~PROMPT
            Tool: #{TOOL_NAME}
            Use for event changes only.
            - action: create | update | delete
            - identify existing event by id/event_id or title/event_title
            - set fields in attributes (title, starts_at, ends_at, duration_minutes, location, priority, description, color, recurring, repeat_days, repeat_until)
            For multiple event changes, use operations: [{action, ...}, ...].
          PROMPT
        end
      end

      private

      def normalize_args(args)
        payload = args.stringify_keys
        payload["model"] = "event"
        payload["operations"] = normalize_operations(payload["operations"], model: "event") if payload["operations"].is_a?(Array)
        payload
      end

      def normalize_operations(operations, model:)
        operations.filter_map do |op|
          next unless op.is_a?(Hash)

          op.stringify_keys.merge("model" => model)
        end
      end
    end
  end
end
