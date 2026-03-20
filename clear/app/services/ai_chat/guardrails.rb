# frozen_string_literal: true

module AiChat
  class Guardrails
    BlockedError = Class.new(StandardError)

    SESSION_BUDGET_KEY = :ai_chat_token_budget
    DEFAULT_MAX_INPUT_CHARS = 2_000
    DEFAULT_MAX_REQUEST_INPUT_TOKENS = 1_500
    DEFAULT_DAILY_TOKEN_BUDGET = 8_000
    ESTIMATED_CHARS_PER_TOKEN = 4.0

    HIGH_COST_PATTERNS = [
      /count\s+from\s+\d+\s+to\s+\d+/i,
      /count\s+to\s+\d{4,}/i,
      /\b1\s*(to|-)\s*1,?000,?000\b/i,
      /\brepeat\b.*\b\d{3,}\b/i,
      /\bprint\b.*\b(thousand|million)\b/i,
      /\bgenerate\b.*\b\d{3,}\b/i
    ].freeze

    class << self
      def preflight!(messages:, session:)
        latest_user_message = latest_user_text(messages)
        total_text = Array(messages).map { |m| m[:content].to_s }.join("\n")

        if latest_user_message.length > max_input_chars
          raise BlockedError, "That request is too long. Please shorten it and try again."
        end

        if high_cost_prompt?(latest_user_message)
          raise BlockedError, "That request is likely to generate excessive output. I can summarize it instead."
        end

        estimated_input_tokens = estimate_tokens(total_text)
        if estimated_input_tokens > max_request_input_tokens
          raise BlockedError, "This request is too large for one response. Please break it into smaller steps."
        end

        enforce_daily_budget!(session: session, additional_tokens: estimated_input_tokens) if session

        {
          estimated_input_tokens: estimated_input_tokens,
          test_mode: test_mode_enabled?
        }
      end

      def postflight!(assistant_text:, session:, estimated_input_tokens:)
        return assistant_text unless session

        used_tokens = estimated_input_tokens + estimate_tokens(assistant_text.to_s)
        budget = current_budget(session)
        budget[:used_tokens] += used_tokens
        session[SESSION_BUDGET_KEY] = budget
        assistant_text
      end

      private

      def latest_user_text(messages)
        latest = Array(messages).reverse.find { |m| m[:role].to_s == "user" }
        latest&.dig(:content).to_s.strip
      end

      def high_cost_prompt?(text)
        prompt = text.to_s.strip
        return false if prompt.blank?

        HIGH_COST_PATTERNS.any? { |pattern| prompt.match?(pattern) }
      end

      def estimate_tokens(text)
        return 0 if text.blank?

        (text.length / ESTIMATED_CHARS_PER_TOKEN).ceil
      end

      def enforce_daily_budget!(session:, additional_tokens:)
        budget = current_budget(session)
        remaining = daily_token_budget - budget[:used_tokens]
        if additional_tokens > remaining
          raise BlockedError, "You've reached today's AI usage budget. Please try again later2."
        end
      end

      def current_budget(session)
        today = Time.zone.today.iso8601
        budget = session[SESSION_BUDGET_KEY]

        if budget.is_a?(Hash) && budget["date"] == today
          { date: budget["date"], used_tokens: budget["used_tokens"].to_i }
        else
          { date: today, used_tokens: 0 }
        end
      end

      def max_input_chars
        ENV.fetch("AI_CHAT_MAX_INPUT_CHARS", DEFAULT_MAX_INPUT_CHARS.to_s).to_i
      end

      def max_request_input_tokens
        ENV.fetch("AI_CHAT_MAX_REQUEST_INPUT_TOKENS", DEFAULT_MAX_REQUEST_INPUT_TOKENS.to_s).to_i
      end

      def daily_token_budget
        ENV.fetch("AI_CHAT_DAILY_TOKEN_BUDGET", DEFAULT_DAILY_TOKEN_BUDGET.to_s).to_i
      end

      def test_mode_enabled?
        ENV["AI_CHAT_TEST_MODE"].to_s == "true"
      end
    end
  end
end
