# frozen_string_literal: true

class SyllabusParseJob < ApplicationJob
  queue_as :default

  def perform(syllabus_id)
    syllabus = Syllabus.find(syllabus_id)

    syllabus.update!(parse_status: "processing", parse_error: nil)

    text  = Syllabuses::TextExtractor.call(syllabus)
    attrs = Syllabuses::CourseAttributesExtractor.call(text, fallback_title: syllabus.title)

    normalize_meeting_days!(attrs)
    remap_attrs_to_course_schema!(attrs)
    attrs = slice_to_course_columns(attrs)

    course = syllabus.course || syllabus.user.courses.new
    course.assign_attributes(attrs)
    course.save!

    syllabus.update!(
      course: course,
      parsed_text: text,
      parsed_at: Time.current,
      parse_status: "done"
    )
  rescue => e
    syllabus&.update(parse_status: "failed", parse_error: "#{e.class}: #{e.message}")
    raise
  end

  private

  def slice_to_course_columns(attrs)
    allowed = Course.column_names.map(&:to_sym)
    attrs.slice(*allowed)
  end

  # Your validation expects "MWF" or "TR" (letters)
  def normalize_meeting_days!(attrs)
    raw = attrs[:meeting_days]
    return if raw.blank?

    if raw.is_a?(String)
      attrs[:meeting_days] = raw.upcase.gsub(/[^MTWRF]/, "").presence
      return
    end

    attrs[:meeting_days] = raw.to_s.upcase.gsub(/[^MTWRF]/, "").presence
  end

  # Map extractor keys to the column names your Course actually uses
  def remap_attrs_to_course_schema!(attrs)
    cols = Course.column_names

    # professor vs instructor
    if cols.include?("instructor") && attrs[:professor].present?
      attrs[:instructor] ||= attrs[:professor]
    end
    if cols.include?("professor") && attrs[:professor].blank? && attrs[:instructor].present?
      attrs[:professor] = attrs[:instructor]
    end

    # starts_at/ends_at vs start_time/end_time
    if cols.include?("start_time") && attrs[:starts_at].present?
      attrs[:start_time] ||= attrs[:starts_at]
    end
    if cols.include?("end_time") && attrs[:ends_at].present?
      attrs[:end_time] ||= attrs[:ends_at]
    end
  end
end
