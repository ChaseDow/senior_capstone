# app/models/document.rb
class Document < ApplicationRecord
  belongs_to :user

  has_one_attached :file

  validates :title, presence: true
  validate :correct_file_type

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/msword
  ].freeze

  def is_pdf?
    file.attached? && file.content_type == "application/pdf"
  end

  private

  def correct_file_type
    return unless file.attached?

    unless file.content_type.in?(ALLOWED_CONTENT_TYPES)
      errors.add(:file, "must be a PDF or DOCX file")
    end
    if file.byte_size > 400_000
      errors.add(:file, "size is over 400 KB")
    end
  end
end
