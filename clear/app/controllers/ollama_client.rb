class OllamaClient
    require "ollama"
    require "timeout"

    class TimeoutError < StandardError; end

    def self.base_url
        ENV.fetch("OLLAMA_BASE_URL")
    end

    def self.base_model
        ENV.fetch("OLLAMA_MODEL")
    end

    def self.read_timeout_seconds
        ENV.fetch("OLLAMA_READ_TIMEOUT_SECONDS", "180").to_i
    end

    def self.chat(messages:, system_prompt: nil)
        if defined?(Excon)
          Excon.defaults[:read_timeout] = read_timeout_seconds
        end

        client = Ollama::Client.new(base_url: base_url)

        payload_messages = []
        if system_prompt.present?
          payload_messages << Ollama::Message.new(role: "system", content: system_prompt)
        end

        payload_messages.concat(
          messages.map { |m| Ollama::Message.new(role: m[:role] || m["role"], content: m[:content] || m["content"]) }
        )

        response = client.chat(
            model: base_model,
            messages: payload_messages,
            stream: false
        )
    response.message.content.to_s
    rescue => e
    if e.class.name == "Excon::Error::Timeout" || e.is_a?(Timeout::Error)
      raise TimeoutError, "Ollama took longer than #{read_timeout_seconds}s to respond."
    end

    raise
    end
end
