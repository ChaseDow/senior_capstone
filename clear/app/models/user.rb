class User < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :syllabuses, dependent: :destroy
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def dev_account?
    %w[chase@example.com landon@example.com].include?(self.email)
  end
end
