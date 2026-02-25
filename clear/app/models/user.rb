class User < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :syllabuses, dependent: :destroy
  has_many :labels, dependent: :destroy

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
        :recoverable, :rememberable, :validatable


  enum :role, { user: 0, admin: 1 }
end
