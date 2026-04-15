class ProjectMessage < ApplicationRecord
  belongs_to :user
  belongs_to :project
  has_many :project_messages, dependent: :destroy

  validates :body, presence: true

  broadcasts_to ->(message) { [ message.project, :project_messages ] }, inserts_at: :bottom
end
