# frozen_string_literal: true

require "ruby_llm"
require "timeout"

module AiChat
  class LlmClient
    class TimeoutError < StandardError; end
    class GuardrailError < StandardError; end

    class << self
      def model
        ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash")
      end

      def chat(messages:, system_prompt: nil, tool_context: nil)
        normalized_messages = normalize_messages(messages)
        user_prompt, prior_messages = split_latest_user_prompt(normalized_messages)
        session = tool_context&.dig(:session)

        guardrails = AiChat::Guardrails.preflight!(messages: normalized_messages, session: session)
        if guardrails[:test_mode]
          return "AI test mode is enabled, so I did not call the model. Ask me to disable AI_CHAT_TEST_MODE when you want live responses."
        end

        chat = RubyLLM.chat(model: model)
        chat.with_instructions(system_prompt) if system_prompt.present?
        prior_messages.each { |m| chat.add_message(role: m[:role], content: m[:content]) }
        chat.with_tool(AiChat::Tooling::CalendarMutationTool)
        # chat.with_tool(AiChat::Tooling::MutateEventTool)
        # chat.with_tool(AiChat::Tooling::MutateCourseTool)
        # chat.with_tool(AiChat::Tooling::MutateCourseItemTool)

        response = if tool_context
          AiChat::Tooling::CalendarMutationTool.with_context(
            user: tool_context.fetch(:user),
            session: tool_context.fetch(:session)
          ) do
            chat.ask(user_prompt)
          end
        else
          chat.ask(user_prompt)
        end

        assistant_text = response.content.to_s
        AiChat::Guardrails.postflight!(
          assistant_text: assistant_text,
          session: session,
          estimated_input_tokens: guardrails[:estimated_input_tokens]
        )
      rescue AiChat::Guardrails::BlockedError => e
        raise GuardrailError, e.message
      rescue Timeout::Error, Faraday::TimeoutError => e
        raise TimeoutError, "Gemini took longer than #{request_timeout_seconds}s to respond. (#{e.class})"
      rescue RubyLLM::ServiceUnavailableError => e
        if e.response&.status == 504
          raise TimeoutError, "Gemini timed out after #{request_timeout_seconds}s."
        end

        raise
      end

      def request_timeout_seconds
        ENV.fetch("RUBY_LLM_REQUEST_TIMEOUT_SECONDS", "180").to_i
      end

      private

      def normalize_messages(messages)
        Array(messages).filter_map do |message|
          role = normalize_role(message[:role] || message["role"])
          content = (message[:content] || message["content"]).to_s.strip
          next if role.nil? || content.blank?

          { role: role, content: content }
        end
      end

      def normalize_role(role)
        case role.to_s
        when "user" then :user
        when "assistant" then :assistant
        when "system" then :system
        end
      end

      def split_latest_user_prompt(messages)
        raise ArgumentError, "messages must include at least one user message" if messages.empty?

        if messages.last[:role] == :user
          prompt = messages.last[:content]
          history = messages[0...-1]
          return [ prompt, history ]
        end

        last_user_index = messages.rindex { |m| m[:role] == :user }
        raise ArgumentError, "messages must include at least one user message" unless last_user_index

        prompt = messages[last_user_index][:content]
        history = messages.dup.tap { |arr| arr.delete_at(last_user_index) }
        [ prompt, history ]
      end
    end
  end
end
