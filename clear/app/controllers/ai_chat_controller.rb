class AiChatController < ApplicationController
  MAX_HISTORY_MESSAGES = 30

  layout "app_shell"
  before_action :authenticate_user!

  def index
    @messages = chat_history.map { |m| { "role" => m.role, "content" => m.content } }
    @message_cap_reached = message_cap_reached?
  end

  def create
    if message_cap_reached?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = cap_reached_message
          @message_cap_reached = true
          render turbo_stream: [
            turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash"),
            turbo_stream.replace("ai_chat_message_form", partial: "ai_chat/message_form", locals: { message_cap_reached: @message_cap_reached })
          ]
        end
        format.html { redirect_to ai_chat_index_path, alert: cap_reached_message }
      end
      return
    end

    user_text = params[:content].to_s.strip

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

    conversation.ai_messages.create!(role: "user", content: user_text)
    ollama_history = chat_history.map { |m| { role: m.role, content: m.content } }
    assistant_text = OllamaClient.chat(messages: ollama_history, system_prompt: AiChat::Toolbox.system_prompt)
    assistant_text = AiChat::Toolbox.run_if_requested(
      raw_reply: assistant_text,
      user: current_user,
      session: session
    )
    conversation.ai_messages.create!(role: "assistant", content: assistant_text)
    trim_history!
    @message_cap_reached = message_cap_reached?

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
          turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash"),
          turbo_stream.replace("ai_chat_message_form", partial: "ai_chat/message_form", locals: { message_cap_reached: @message_cap_reached }),
          turbo_stream.update("ai_chat_input", "")
        ]
      end

      format.html do
        @messages = chat_history.map { |m| { "role" => m.role, "content" => m.content } }
        @message_cap_reached = message_cap_reached?
        render :index
      end
    end
  rescue OllamaClient::TimeoutError => e
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "AI request timed out. #{e.message} Try again, or increase OLLAMA_READ_TIMEOUT_SECONDS."
        render turbo_stream: turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash")
      end
      format.html { redirect_to ai_chat_index_path, alert: "AI request timed out. #{e.message}" }
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

  def reset
    conversation.ai_messages.delete_all
    @message_cap_reached = false

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Conversation reset."
        render turbo_stream: [
          turbo_stream.update("ai_chat_messages", ""),
          turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash"),
          turbo_stream.replace("ai_chat_message_form", partial: "ai_chat/message_form", locals: { message_cap_reached: @message_cap_reached })
        ]
      end
      format.html { redirect_to ai_chat_index_path, notice: "Conversation reset." }
    end
  end

  private

  def chat_history
    conversation.ai_messages.order(id: :desc).limit(MAX_HISTORY_MESSAGES).reverse
  end

  def conversation
    @conversation ||= current_user.ai_conversation || current_user.create_ai_conversation!
  end

  def trim_history!
    extra_count = conversation.ai_messages.count - MAX_HISTORY_MESSAGES
    return unless extra_count.positive?

    stale_ids = conversation.ai_messages.order(:id).limit(extra_count).pluck(:id)
    conversation.ai_messages.where(id: stale_ids).delete_all
  end

  def message_cap_reached?
    conversation.ai_messages.count >= MAX_HISTORY_MESSAGES
  end

  def cap_reached_message
    "Message cap reached. Click Reset to start a new conversation."
  end
end
