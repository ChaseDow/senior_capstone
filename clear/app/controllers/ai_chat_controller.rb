class AiChatController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def index
    session[:ai_chat] ||= []
    @messages = session[:ai_chat]
  end

  def create
    session[:ai_chat] ||= []
    user_text = params[:content].to_s.strip

    if user_text.blank?
      redirect_to ai_chat_index_path, alert: "Message can't be blank."
      return
    end

    session[:ai_chat] << { "role" => "user", "content" => user_text }

    history = session[:ai_chat].map { |m| { role: m["role"], content: m["content"] } }
    assistant_text = OllamaClient.chat(messages: history)

    session[:ai_chat] << { "role" => "assistant", "content" => assistant_text }

    redirect_to ai_chat_index_path
  rescue => e
    redirect_to ai_chat_index_path, alert: "AI error: #{e.message}"
  end
end
