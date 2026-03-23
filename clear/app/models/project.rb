class Project < ApplicationRecord
  before_create :generate_invite_token
  has_many :events, dependent: :destroy
  has_many :courses, dependent: :destroy

  has_many :project_memberships, dependent: :destroy
  has_many :users, through: :project_memberships, source: :user
  has_many :project_invitations, dependent: :destroy

  validates :title, presence: true

  def generate_invite_token
    self.invite_token = SecureRandom.hex(10)
  end
end
