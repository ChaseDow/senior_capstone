# frozen_string_literal: true

class CourseItem < ApplicationRecord
  belongs_to :course

  enum :kind, {
    assignment: 0,
    quiz: 1,
    exam: 2,
    project: 3,
    reading: 4,
    lab: 5,
    presentation: 6,
    seminar: 7,
    other: 8
  }

  validates :title, presence: true
  validates :kind, presence: true
  validates :due_at, presence: true

  def title
    base = self[:title]
    course_name = course&.title.presence || "Course"
    kind_name = self[:kind].present? ? kind.humanize : "Item"

    if base.present?
      "#{course_name} — #{kind_name}: #{base}"
    else
      "#{course_name} — #{kind_name}"
    end
  end

  def raw_title = self[:title]

  def starts_at = due_at

  def ends_at = due_at + 30.minutes

  def color = course.color

  def contrast_text_color
    course.respond_to?(:contrast_text_color) ? course.contrast_text_color : "#F9FAFB"
  end
end
