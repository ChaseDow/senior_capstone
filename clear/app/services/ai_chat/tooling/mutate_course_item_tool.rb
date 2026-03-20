# frozen_string_literal: true

require "ruby_llm"

module AiChat
  module Tooling
    class MutateCourseItemTool < RubyLLM::Tool
      TOOL_NAME = "mutate_course_item"

      description "Create, update, or delete course item drafts."
      param :action
      param :id
      param :title
      param :target_title
      param :from_title
      param :new_title
      param :rename_to
      param :course_id
      param :course_title
      param :course_code
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
        Rails.logger.error("MutateCourseItemTool error: #{e.class}: #{e.message}")
        "I couldn't complete that course item change right now. Please try again with the item title, due time, and course."
      end

      class << self
        def prompt_instructions
          <<~PROMPT
            Tool: #{TOOL_NAME}
            Use for course item changes only (assignment/quiz/exam/project/etc).
            - action: create | update | delete
            - identify existing item by id or title
            - set fields in attributes (title, kind, due_at, details, course_id)
            - include course_id, course_title, or course_code for item creation when possible.
            For multiple course item changes, use operations: [{action, ...}, ...].
          PROMPT
        end
      end

      private

      def normalize_args(args)
        payload = args.stringify_keys
        payload["model"] = "course_item"
        payload["operations"] = normalize_operations(payload["operations"], model: "course_item") if payload["operations"].is_a?(Array)
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
