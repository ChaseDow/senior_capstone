# frozen_string_literal:true

class Schedule < ApplicationRecord
    belongs_to :user
    validates :user, presence: true
    validates :name, presence: true
    validates :timezone, presence: true
    validates :week_starts_on, presence: true
    validates :active, presence: true
end
