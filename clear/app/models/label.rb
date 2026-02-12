class Label < ApplicationRecord
  belongs_to :user

  validates :name, presence: true,
                   uniqueness: { scope: :user_id, case_sensitive: false }

  # optional: normalize so "Work" and " work " become the same
  before_validation :normalize_name

  private

  def normalize_name
    self.name = name.to_s.strip
  end
end
