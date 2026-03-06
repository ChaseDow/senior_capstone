class OllamaClient
    require "ollama"
    
    def self.base_url
        ENV.fetch("OLLAMA_BASE_URL")
    end

    def self.base_model
        ENV.fetch("OLLAMA_MODEL")
    end

    def self.chat(messages:)
        client = Ollama::Client.new(base_url: base_url)

        response = client.chat(
            model: base_model,
            messages: messages.map { |m| Ollama::Message.new(role: m[:role] || m["role"], content: m[:content] || m["content"]) },
            stream: false
        )
    response.message.content.to_s
    end

end