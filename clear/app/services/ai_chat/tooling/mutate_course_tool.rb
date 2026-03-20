# frozen_string_literal: true

require "ruby_llm"

module AiChat
  module Tooling
    class MutateCourseTool < RubyLLM::Tool
      TOOL_NAME = "mutate_course"

      description "Create, update, or delete course drafts."
      param :action
      param :id
      param :title
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
        Rails.logger.error("MutateCourseTool error: #{e.class}: #{e.message}")
        "I couldn't complete that course change right now. Please try again with the course title and schedule details."
      end

      class << self
        def prompt_instructions
          <<~PROMPT
            Tool: #{TOOL_NAME}
            Use for course changes only.
            - action: create | update | delete
            - identify existing course by id or title
            - set fields in attributes (title, code, term, color, start_date, end_date, start_time, end_time, duration_minutes, professor, instructor, location, description, repeat_days, meeting_days)
            Courses are recurring items; include repeat_days or meeting_days when creating.
            For multiple course changes, use operations: [{action, ...}, ...].
          PROMPT
        end
      end

      private

      def normalize_args(args)
        payload = args.stringify_keys
        payload["model"] = "course"
        payload["operations"] = normalize_operations(payload["operations"], model: "course") if payload["operations"].is_a?(Array)
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
