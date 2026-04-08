class AiConversation < ApplicationRecord
  belongs_to :user
  has_many :ai_chat_messages, dependent: :destroy

  validates :user_id, uniqueness: true
end
