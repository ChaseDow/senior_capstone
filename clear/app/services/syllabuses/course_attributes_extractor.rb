# frozen_string_literal: true

require "date"

module Syllabuses
  class CourseAttributesExtractor
    COURSE_CODE = /\b[A-Z]{2,4}\s?\d{3,4}(?:-\d{3})?\b/
    TERM        = /\b(?<season>Spring|Summer|Fall|Winter)\s*(?<year>20\d{2})\b/i

    # Instructor / Professor line
    INSTRUCTOR_LINE = /\A(?:Instructor|Professor)\s*:\s*(?<name>.+)\z/i

    # Numeric outline dates: (12/09,11,16/2025)
    OUTLINE_DATES_NUM = /(?<month>\d{1,2})\/(?<days>\d{1,2}(?:,\d{1,2})*)\/(?<year>\d{4})/

    MONTHS = {
      "january" => 1, "february" => 2, "march" => 3, "april" => 4,
      "may" => 5, "june" => 6, "july" => 7, "august" => 8,
      "september" => 9, "october" => 10, "november" => 11, "december" => 12
    }.freeze

    OUTLINE_DATE_MONTH = /\A(?<month>January|February|March|April|May|June|July|August|September|October|November|December)\s+(?<day>\d{1,2})\b/i
    LAST_DAY_OF_CLASS  = /Last Day of Class\b.*?(?<date>(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4})/i

    def self.call(text, fallback_title:)
      lines = normalize_lines(text)
      flat  = lines.join(" ")

      term_match = flat.match(TERM)
      season     = term_match&.[](:season)&.capitalize
      term_year  = term_match&.[](:year)&.to_i
      term       = term_match&.to_s

      code = flat.match(COURSE_CODE)&.to_s&.gsub(/\s+/, " ")

      professor = extract_professor(lines)

      meeting = Syllabuses::MeetingInfoExtractor.call(lines)
      meeting_days     = meeting&.dig(:meeting_days)
      starts_at        = meeting&.dig(:starts_at)
      ends_at          = meeting&.dig(:ends_at)
      location         = meeting&.dig(:location)
      meeting_raw      = meeting&.dig(:meeting_raw)
      parse_confidence = meeting&.dig(:confidence)

      start_date, end_date = extract_date_range(text, lines, season:, term_year:)

      {
        title: fallback_title.presence || "Untitled Course",
        code: code,
        term: term,
        professor: professor,

        # meeting info
        meeting_days: meeting_days,
        starts_at: starts_at,
        ends_at: ends_at,
        location: location,

        # dates
        start_date: start_date,
        end_date: end_date,

        # debugging / quality
        meeting_raw: meeting_raw,
        parse_confidence: parse_confidence
      }.compact
    end

    # ---------------- helpers ----------------

    def self.normalize_lines(text)
      text.to_s
          .gsub("\u00A0", " ")
          .tr("\u2013\u2014\u2212", "-") # en dash/em dash/minus -> "-"
          .lines
          .map { |l| normalize_text(l.strip) }
          .reject(&:empty?)
    end

    def self.normalize_text(s)
      s.to_s
       .gsub(/[’‘`]/, "")
       .gsub(/\\/, "")
       .gsub(/\s+/, " ")
       .strip
    end

    def self.extract_professor(lines)
      line = lines.find { |l| l.match?(INSTRUCTOR_LINE) }
      return nil unless line

      name = line.match(INSTRUCTOR_LINE)[:name].strip
      name = name.split(/\s{2,}|\s+-\s+/).first.to_s.strip
      name.presence
    end

    def self.extract_date_range(text, lines, season:, term_year:)
      return [ nil, nil ] unless term_year

      dates = []

      explicit_end = nil
      if (line = lines.find { |l| l.match?(LAST_DAY_OF_CLASS) })
        explicit_end = Date.parse(line.match(LAST_DAY_OF_CLASS)[:date]) rescue nil
      end

      # numeric style (often in tables like 12/09,11,16/2025)
      text.to_s.scan(OUTLINE_DATES_NUM) do |month, days, year|
        m = month.to_i
        y = normalize_outline_year(season, term_year, m, year.to_i)
        days.split(",").each do |d|
          dates << Date.new(y, m, d.to_i) rescue nil
        end
      end

      # month-name style (March 14 ...)
      lines.each do |l|
        m = l.match(OUTLINE_DATE_MONTH)
        next unless m

        month_num = MONTHS[m[:month].downcase]
        day_num   = m[:day].to_i
        dates << Date.new(term_year, month_num, day_num) rescue nil
      end

      dates.compact!
      return [ nil, nil ] if dates.empty?

      [ dates.min, explicit_end || dates.max ]
    end

    # Winter terms usually span Dec (previous year) -> Mar (term year)
    def self.normalize_outline_year(season, term_year, month, year)
      return year unless season == "Winter"

      expected = month >= 10 ? (term_year - 1) : term_year
      (year - expected).abs <= 1 ? expected : year
    end
  end
end
