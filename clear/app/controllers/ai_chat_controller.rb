class AiChatController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def index
    @messages = previous_messages
    @rate = GeminiRateTracker.usage
  end

  def usage
    render json: GeminiRateTracker.usage
  end

  def create
    user_text = params[:content].to_s.strip
    history   = previous_messages

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

    rate = GeminiRateTracker.usage
    if rate[:rpd] >= rate[:rpd_limit]
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Daily AI limit reached (#{rate[:rpd_limit]} requests). Resets at midnight."
          render turbo_stream: turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash")
        end
        format.html { redirect_to ai_chat_index_path, alert: "Daily AI limit reached." }
      end
      return
    end

    if rate[:rpm] >= rate[:rpm_limit]
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Slow down — rate limit is #{rate[:rpm_limit]} requests per minute. Wait a moment and try again."
          render turbo_stream: turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash")
        end
        format.html { redirect_to ai_chat_index_path, alert: "Rate limit reached, try again shortly." }
      end
      return
    end

    ai_conversation.ai_chat_messages.create!(role: "user", content: user_text)
    history << { "role" => "user", "content" => user_text }

    chat_history = trim_for_api(history)
    system_inst = AiTools::SystemInstructionBuilder.call(user: current_user)
    tools = gemini_tools

    result = GeminiClient.chat(messages: chat_history, system_instruction: system_inst, tools: tools)
    GeminiRateTracker.record!

    # Handle function calls
    if result[:function_call]
      fc = result[:function_call]
      fn_response = execute_function(fc[:name], fc[:args])

      chat_history << { role: "assistant", parts: [ { functionCall: { name: fc[:name], args: fc[:args] } } ] }

      final = GeminiClient.continue_with_function_response(
        messages: chat_history,
        function_name: fc[:name],
        response_data: fn_response,
        system_instruction: system_inst,
        tools: tools
      )
      GeminiRateTracker.record!
      assistant_text = final[:text]
    else
      assistant_text = result[:text]
    end

    ai_conversation.ai_chat_messages.create!(role: "assistant", content: assistant_text.to_s)
    history << { "role" => "assistant", "content" => assistant_text }
    updated_rate = GeminiRateTracker.usage

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
          turbo_stream.update("ai_chat_input", ""),
          turbo_stream.replace("ai_chat_usage", partial: "ai_chat/usage", locals: { rate: updated_rate })
        ]
      end

      format.html do
        @messages = history
        @rate = updated_rate
        render :index
      end
    end
  rescue GeminiClient::RateLimitExhausted => e
    GeminiRateTracker.record!
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = e.message
        render turbo_stream: turbo_stream.replace("ai_chat_flash", partial: "ai_chat/flash")
      end
      format.html { redirect_to ai_chat_index_path, alert: e.message }
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

  def gemini_tools
    [ {
      functionDeclarations: AiTools::Registry.declarations
    } ]
  end

  def execute_function(name, args)
    AiTools::Registry.execute(name: name, user: current_user, args: args)
  end

  API_HISTORY_LIMIT = 20

  def trim_for_api(history)
    trimmed = if history.length > API_HISTORY_LIMIT
      [ { role: "user", content: "Previous conversation context has been trimmed for efficiency." },
        { role: "assistant", content: "Understood, I'll continue from the recent messages." } ] +
        history.last(API_HISTORY_LIMIT).map { |m| { role: m["role"], content: m["content"] } }
    else
      history.map { |m| { role: m["role"], content: m["content"] } }
    end
    trimmed
  end

  def ai_conversation
    @ai_conversation ||= current_user.ai_conversation || current_user.create_ai_conversation!
  end

  def previous_messages
    ai_conversation.ai_chat_messages
      .order(:created_at)
      .last(API_HISTORY_LIMIT)
      .map { |m| { "role" => m.role, "content" => m.content } }
  end
end
