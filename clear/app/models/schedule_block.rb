# frozen_string_literal:true

class ScheduleBlock < ApplicationRecord
    belongs_to :schedule
    validates :day_of_week, presence: true
    validates :start_time, presence: true
    validates :end_time, presence: true
    validates :title, presence: true
    validates :category, presence: true
    validates :locked, presence: true
    validates :position, presence: true