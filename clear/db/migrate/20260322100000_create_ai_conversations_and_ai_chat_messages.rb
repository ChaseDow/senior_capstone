class CreateAiConversationsAndAiChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_conversations, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end

    create_table :ai_chat_messages, if_not_exists: true do |t|
      t.references :ai_conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false

      t.timestamps
    end

    add_index :ai_chat_messages, [ :ai_conversation_id, :created_at ], if_not_exists: true
    add_index :ai_chat_messages, :role, if_not_exists: true
  end
end
