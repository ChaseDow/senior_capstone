class OllamaClient
    require "net/http"
    require "json"
    def self.base_url
        ENV.fetch("OLLAMA_BASE_URL")
    end

    def self.chat(messages:, model: ENV.fetch("OLLAMA_MODEL"))
        uri = URI("#{base_url}/api/chat")
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        req.body = { model: model, messages: messages, stream: false }.to_json
        res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
        raise "Ollama error #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body).dig("message", "content").to_s
    end
end
