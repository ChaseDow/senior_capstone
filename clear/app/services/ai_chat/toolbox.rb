# frozen_string_literal: true

module AiChat
  class Toolbox
    class << self
      def system_prompt(current_user: nil)
        <<~PROMPT
          Current local datetime (authoritative): #{Time.zone.now.strftime("%Y-%m-%d %H:%M %Z")}.
          Current local date (authoritative): #{Time.zone.today.iso8601}.
          If asked for today's date/time, use the authoritative values above.

          You can call one function tool when needed.
          If the user requests multiple calendar changes in one message, make one tool call and use operations for all requested changes.
          If the user says this is a different/new item, prefer create instead of update.

          #{AiChat::Tooling::CalendarMutationTool.prompt_instructions}

          If no tool is needed, answer normally using the schedule context below.
          #{schedule_context_for(current_user)}
        PROMPT
      end

      private

      def schedule_context_for(current_user)
        return "" unless current_user

        AiChat::Context::WeeklyScheduleBuilder.call(current_user: current_user)
      end
    end
  end
end
