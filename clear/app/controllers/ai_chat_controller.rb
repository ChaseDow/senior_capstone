class AiChatController < ApplicationController
  MAX_HISTORY_MESSAGES = 30

  layout "app_shell"
  before_action :authenticate_user!

  def index
    @messages = formatted_chat_history
    @message_cap_reached = message_cap_reached?
  end

  def create
    if message_cap_reached?
      @message_cap_reached = true
      render_alert(cap_reached_message, replace_message_form: true)
      return
    end

    user_text = params[:content].to_s.strip

    if user_text.blank?
      render_alert("Message can't be blank.")
      return
    end

    conversation.ai_messages.create!(role: "user", content: user_text)
    llm_history = chat_history.map { |m| { role: m.role, content: m.content } }
    assistant_text = AiChat::LlmClient.chat(
      messages: llm_history,
      system_prompt: AiChat::Toolbox.system_prompt(current_user: current_user),
      tool_context: { user: current_user, session: session }
    )
    conversation.ai_messages.create!(role: "assistant", content: assistant_text)
    trim_history!
    @message_cap_reached = message_cap_reached?

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: chat_create_streams(user_text: user_text, assistant_text: assistant_text)
      end

      format.html do
        @messages = formatted_chat_history
        render :index
      end
    end
  rescue AiChat::LlmClient::TimeoutError => e
    render_alert(
      "AI request timed out. #{e.message}",
      turbo_message: "AI request timed out. #{e.message} Try again, or increase RUBY_LLM_REQUEST_TIMEOUT_SECONDS."
    )
  rescue AiChat::LlmClient::GuardrailError => e
    render_alert(e.message)
  rescue => e
    render_alert("AI error: #{e.message}")
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

  def formatted_chat_history
    chat_history.map { |message| { "role" => message.role, "content" => message.content } }
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

  def chat_create_streams(user_text:, assistant_text:)
    [
      turbo_stream.append("ai_chat_messages", partial: "ai_chat/message", locals: { m: { "role" => "user", "content" => user_text } }),
      turbo_stream.append("ai_chat_messages", partial: "ai_chat/message", locals: { m: { "role" => "assistant", "content" => assistant_text }, animate: true }),
      turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash"),
      turbo_stream.replace("ai_chat_message_form", partial: "ai_chat/message_form", locals: { message_cap_reached: @message_cap_reached }),
      turbo_stream.update("ai_chat_input", "")
    ]
  end

  def render_alert(html_message, turbo_message: html_message, replace_message_form: false)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = turbo_message
        streams = [ turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash") ]
        streams << turbo_stream.replace("ai_chat_message_form", partial: "ai_chat/message_form", locals: { message_cap_reached: @message_cap_reached }) if replace_message_form
        render turbo_stream: streams
      end
      format.html { redirect_to ai_chat_index_path, alert: html_message }
    end
  end

  def cap_reached_message
    "Message cap reached. Click Reset to start a new conversation."
  end
end
