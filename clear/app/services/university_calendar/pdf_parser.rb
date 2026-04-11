# frozen_string_literal: true

require "stringio"
require "pdf/reader"
require "date"
require "set"

module UniversityCalendar
  class PdfParser
    MONTH_NAMES = {
      "january" => 1, "february" => 2, "march" => 3, "april" => 4,
      "may" => 5, "june" => 6, "july" => 7, "august" => 8,
      "september" => 9, "october" => 10, "november" => 11, "december" => 12,
      "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4,
      "jun" => 6, "jul" => 7, "aug" => 8,
      "sep" => 9, "sept" => 9, "oct" => 10, "nov" => 11, "dec" => 12
    }.freeze

    MONTH_RE   = /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?/i
    WEEKDAY_RE = /(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tues?|Wed|Thur?s?|Fri|Sat|Sun)\.?/i

    # "August 25 - September 1" or "Aug 25-27" — try range before single date
    DATE_RANGE = /(?<sm>#{MONTH_RE})\s+(?<sd>\d{1,2})\s*[-–]\s*(?:(?<em>#{MONTH_RE})\s+)?(?<ed>\d{1,2})\b/

    # "August 25" or "Aug. 25"
    MONTH_DAY = /(?<month>#{MONTH_RE})\s+(?<day>\d{1,2})\b/

    # Tabular row without month: "11 Monday Event" or "9 - 12 Thursday Fall Break"
    TABULAR_ROW = /\A(?<sd>\d{1,2})(?:\s*[-–]\s*(?<ed>\d{1,2}))?\s+(?<wd>#{WEEKDAY_RE})\b\s*(?<rest>.*)\z/

    # Month-only line (possibly with trailing whitespace): "August"
    MONTH_ONLY = /\A(?<month>#{MONTH_RE})\s*\z/

    # Semester header: "FALL SEMESTER 2025", "Spring Semester 2026"
    SEMESTER_HEADER = /\b(?<season>fall|spring|summer|winter)\s+semester\b(?:\s+(?<year>20\d{2}))?/i

    # Academic year range: "2025 - 2026"
    ACADEMIC_YEAR_RANGE = /(?<y1>20\d{2})\s*[-–]\s*(?<y2>20\d{2})/

    SKIP_LINE = /\A\s*(?:\d{4}\s*\z|page\s+\d+|table\s+of\s+contents\s*\z|academic\s+calendar\s*\z|semester\s+calendar\s*\z|last\s+updated)/i

    def self.call(pdf_data)
      reader = PDF::Reader.new(StringIO.new(pdf_data))
      text = reader.pages.map(&:text).join("\n")
      new(text).parse
    end

    def initialize(text)
      @text = text
      @fall_year, @spring_year = extract_academic_years(text)
      @fall_year   ||= extract_year(text)
      @spring_year ||= (@fall_year ? @fall_year + 1 : nil)
    end

    def parse
      lines = normalize_lines(@text)
      items = []

      state = {
        current_month: nil,
        current_year:  @fall_year,
        semester:      :fall
      }

      lines.each do |line|
        next if SKIP_LINE.match?(line)
        next if line.strip.length < 3

        # Semester header — update year context, skip line.
        if (m = line.match(SEMESTER_HEADER))
          season = m[:season].downcase.to_sym
          state[:semester]     = season
          state[:current_year] = m[:year]&.to_i || year_for_semester(season)
          next
        end

        # Month-only line — update current_month, skip line.
        if (m = line.match(MONTH_ONLY)) && (month = resolve_month(m[:month]))
          state[:current_month] = month
          next
        end

        event = extract_event(line, state)
        items << event if event
      end

      deduplicate(items)
    end

    private

    def extract_event(line, state)
      # Case 1: "Month Day - [Month] Day" date range
      if (m = line.match(DATE_RANGE))
        start_month = resolve_month(m[:sm])
        end_month   = m[:em].present? ? resolve_month(m[:em]) : start_month
        return nil unless start_month

        state[:current_month] = end_month || start_month

        start_year = state[:current_year] || infer_year(start_month)
        end_year   = start_year
        end_year  += 1 if end_month && end_month < start_month

        starts_at = safe_date(start_year, start_month, m[:sd].to_i)
        ends_at   = safe_date(end_year, end_month, m[:ed].to_i)
        return nil unless starts_at

        title = clean_title(line, m[0])
        return nil if title.blank?

        return { title: title, starts_at: starts_at.to_time, ends_at: ends_at&.to_time, all_day: true }
      end

      # Case 2: "Month Day" single date (possibly followed by weekday + event)
      if (m = line.match(MONTH_DAY))
        month = resolve_month(m[:month])
        if month
          state[:current_month] = month
          year = state[:current_year] || infer_year(month)
          date = safe_date(year, month, m[:day].to_i)

          if date
            title = clean_title(line, m[0])
            return nil if title.blank?
            return { title: title, starts_at: date.to_time, ends_at: nil, all_day: true }
          end
        end
      end

      # Case 3: Tabular row "Day [- Day] Weekday Event" — uses current_month from state
      if (m = line.match(TABULAR_ROW)) && state[:current_month]
        month = state[:current_month]
        year  = state[:current_year] || infer_year(month)

        starts_at = safe_date(year, month, m[:sd].to_i)
        return nil unless starts_at

        ends_at = m[:ed] ? safe_date(year, month, m[:ed].to_i) : nil

        title = clean_title(m[:rest].to_s, "")
        return nil if title.blank?

        return { title: title, starts_at: starts_at.to_time, ends_at: ends_at&.to_time, all_day: true }
      end

      nil
    end

    def clean_title(line, date_str)
      title = date_str.present? ? line.sub(date_str, "") : line.dup
      # Strip a leading weekday left over after removing the date.
      title = title.sub(/\A\s*#{WEEKDAY_RE}\b\.?/, "")
      title = title.gsub(/\A\s*[-–:,;.•*]\s*/, "")
      title = title.gsub(/\s*[-–:,;.]\s*\z/, "")
      title = title.strip.squeeze(" ")
      title = title[0, 120].sub(/\s+\S*\z/, "") if title.length > 120
      title.presence
    end

    def resolve_month(str)
      MONTH_NAMES[str.to_s.downcase.delete(".").strip]
    end

    def safe_date(year, month, day)
      return nil if year.nil? || month.nil? || day.nil?

      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end

    def year_for_semester(season)
      case season
      when :fall, :winter   then @fall_year
      when :spring, :summer then @spring_year
      end
    end

    def extract_year(text)
      m = text.match(/\b(20\d{2})\b/)
      m ? m[1].to_i : nil
    end

    def extract_academic_years(text)
      m = text.match(ACADEMIC_YEAR_RANGE)
      return [nil, nil] unless m

      y1 = m[:y1].to_i
      y2 = m[:y2].to_i
      # Only treat as an academic range if the years are consecutive.
      return [nil, nil] unless y2 == y1 + 1

      [y1, y2]
    end

    def infer_year(month)
      today = Date.today
      today.month >= 8 && month.between?(1, 7) ? today.year + 1 : today.year
    end

    def normalize_lines(text)
      text.gsub("\u00A0", " ")
          .tr("\u2013\u2014\u2212", "-")
          .lines
          .map { |l| l.strip.gsub(/\s+/, " ") }
          .reject(&:empty?)
    end

    def deduplicate(items)
      seen = Set.new
      items.select do |item|
        key = "#{item[:title].downcase.strip}|#{item[:starts_at]&.to_date}"
        seen.add?(key)
      end
    end
  end
end
