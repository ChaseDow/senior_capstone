# frozen_string_literal: true

require "ruby_llm"

RubyLLM.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil)
  config.request_timeout = ENV.fetch("RUBY_LLM_REQUEST_TIMEOUT_SECONDS", "180").to_i
end
