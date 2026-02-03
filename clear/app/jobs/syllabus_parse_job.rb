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

    draft = slice_to_course_columns(attrs)
    draft = normalize_values_for_json(draft)

    syllabus.update!(
      course_draft: draft,
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

  def normalize_values_for_json(attrs)
    attrs.transform_values do |v|
      case v
      when Date
        v.iso8601
      else
        v
      end
    end
  end

  def normalize_meeting_days!(attrs)
    raw = attrs[:meeting_days]
    return if raw.blank?

    attrs[:meeting_days] = raw.to_s.upcase.gsub(/[^MTWRF]/, "").presence
  end

  def remap_attrs_to_course_schema!(attrs)
    cols = Course.column_names

    # professor vs instructor
    if cols.include?("instructor") && attrs[:professor].present?
      attrs[:instructor] ||= attrs[:professor]
    end
    if cols.include?("professor") && attrs[:professor].blank? && attrs[:instructor].present?
      attrs[:professor] = attrs[:instructor]
    end

    if cols.include?("start_time") && attrs[:starts_at].present?
      attrs[:start_time] ||= attrs[:starts_at]
    end
    if cols.include?("end_time") && attrs[:ends_at].present?
      attrs[:end_time] ||= attrs[:ends_at]
    end
  end
end
