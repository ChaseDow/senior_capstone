class User < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :syllabuses, dependent: :destroy

  devise :database_authenticatable, :registerable,
        :recoverable, :rememberable, :validatable

  enum :role, { user: 0, admin: 1 }
  has_one_attached :avatar

  def avatar_thumbnail
    avatar.variant(resize: "150x150!").processed
  end
end
