# app/models/syllabus.rb
class Syllabus < ApplicationRecord
  belongs_to :user
  has_one_attached :file

  validates :title, presence: true
  validate :correct_file_type

  # Scope to get syllabuses with attachments
  scope :with_files, -> { joins(:file_attachment) }

  # Allowed file types
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/msword
  ].freeze

  def file_extension
    return nil unless file.attached?
    File.extname(file.filename.to_s).downcase
  end

  def is_pdf?
    file.attached? && file.content_type == "application/pdf"
  end

  def is_docx?
    file.attached? && file.content_type.in?([
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/msword"
    ])
  end

  private

  def correct_file_type
    if file.attached? && !file.content_type.in?(ALLOWED_CONTENT_TYPES)
      errors.add(:file, "must be a PDF or DOCX file")
    end
  end
end
