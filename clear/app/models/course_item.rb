# frozen_string_literal: true

class CourseItem < ApplicationRecord
  belongs_to :course
  has_many :notifications, as: :notifiable, dependent: :destroy

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

  after_create_commit :create_assignment_notification

  def display_title
    course_name = course&.title.presence || "Course"
    kind_name   = kind.present? ? kind.humanize : "Item"
    base        = self[:title].presence

    base ? "#{course_name} — #{kind_name}: #{base}" : "#{course_name} — #{kind_name}"
  end

  private

  def create_assignment_notification
    Notification.create!(
      user: course.user,
      notifiable: self,
      category: "assignment_due",
      message: "#{kind.humanize} due: #{title}"
    )
  end

  public

  def starts_at = due_at
  def ends_at = due_at ? due_at + 30.minutes : nil
  def color = course.color

  def contrast_text_color
    course.respond_to?(:contrast_text_color) ? course.contrast_text_color : "#F9FAFB"
  end
end
