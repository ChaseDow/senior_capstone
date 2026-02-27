# app/controllers/ai_chat_controller.rb
class AiChatController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def index
    @messages = []
  end

  def create
    user_text = params[:content].to_s.strip
    history   = parse_history(params[:history])

    if user_text.blank?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Message can't be blank."
          render turbo_stream: turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash")
        end
        format.html { redirect_to ai_chat_index_path, alert: "Message can't be blank." }
      end
      return
    end

    # user message
    history << { "role" => "user", "content" => user_text }

    # assistant message
    ollama_history = history.map { |m| { role: m["role"], content: m["content"] } }
    assistant_text = OllamaClient.chat(messages: ollama_history)

    history << { "role" => "assistant", "content" => assistant_text }

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("ai_chat_messages",
            partial: "ai_chat/message",
            locals: { m: { "role" => "user", "content" => user_text } }
          ),
          turbo_stream.append("ai_chat_messages",
            partial: "ai_chat/message",
            locals: { m: { "role" => "assistant", "content" => assistant_text } }
          ),
          turbo_stream.update("ai_chat_history", history.to_json),
          turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash"),
          turbo_stream.update("ai_chat_input", "") # clears textarea
        ]
      end

      # fallback (non-turbo)
      format.html do
        @messages = history
        render :index
      end
    end
  rescue => e
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "AI error: #{e.message}"
        render turbo_stream: turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash")
      end
      format.html { redirect_to ai_chat_index_path, alert: "AI error: #{e.message}" }
    end
  end

  private

  def parse_history(raw)
    return [] if raw.blank?
    arr = JSON.parse(raw)
    return [] unless arr.is_a?(Array)
    arr = arr.select { |m| m.is_a?(Hash) && m["role"].present? && m["content"].present? }
    arr.last(50)
  rescue JSON::ParserError
    []
  end
end
