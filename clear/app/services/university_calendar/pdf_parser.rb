# frozen_string_literal: true

require "stringio"
require "pdf/reader"
require "date"

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

    MONTH_RE = /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?/i

    # "August 25 - September 1" or "Aug 25-27" — try range before single date
    DATE_RANGE = /(?<sm>#{MONTH_RE})\s+(?<sd>\d{1,2})\s*[-–]\s*(?:(?<em>#{MONTH_RE})\s+)?(?<ed>\d{1,2})/

    # "August 25" or "Aug. 25"
    MONTH_DAY = /(?<month>#{MONTH_RE})\s+(?<day>\d{1,2})/

    SKIP_LINE = /\A\s*(\d{4}|page\s+\d+|table\s+of\s+contents|academic\s+calendar\s*\z|semester\s+calendar\s*\z)/i

    def self.call(pdf_data)
      reader = PDF::Reader.new(StringIO.new(pdf_data))
      text = reader.pages.map(&:text).join("\n")
      new(text).parse
    end

    def initialize(text)
      @text = text
      @year = extract_year(text)
    end

    def parse
      lines = normalize_lines(@text)
      items = []

      lines.each do |line|
        next if line.match?(SKIP_LINE)
        next if line.strip.length < 5

        result = extract_event(line)
        items << result if result
      end

      deduplicate(items)
    end

    private

    def extract_event(line)
      if (m = line.match(DATE_RANGE))
        start_month = resolve_month(m[:sm])
        end_month   = m[:em].present? ? resolve_month(m[:em]) : start_month
        return nil unless start_month

        start_year = @year || infer_year(start_month)
        end_year   = @year || infer_year(end_month)

        starts_at = safe_date(start_year, start_month, m[:sd].to_i)
        ends_at   = safe_date(end_year, end_month, m[:ed].to_i)
        return nil unless starts_at

        title = clean_title(line, m[0])
        return nil if title.blank?

        { title: title, starts_at: starts_at.to_time, ends_at: ends_at&.to_time, all_day: true }

      elsif (m = line.match(MONTH_DAY))
        month = resolve_month(m[:month])
        return nil unless month

        year = @year || infer_year(month)
        date = safe_date(year, month, m[:day].to_i)
        return nil unless date

        title = clean_title(line, m[0])
        return nil if title.blank?

        { title: title, starts_at: date.to_time, ends_at: nil, all_day: true }

      else
        nil
      end
    end

    def clean_title(line, date_str)
      title = line.sub(date_str, "")
      title = title.gsub(/\A\s*[-–:,;.•*\d]\s*/, "")
      title = title.gsub(/\s*[-–:,;.]\s*\z/, "")
      title = title.strip.squeeze(" ")
      title = title[0, 100].sub(/\s+\S*\z/, "") if title.length > 100
      title.presence
    end

    def resolve_month(str)
      MONTH_NAMES[str.to_s.downcase.delete(".").strip]
    end

    def safe_date(year, month, day)
      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end

    def extract_year(text)
      m = text.match(/\b(20\d{2})\b/)
      m ? m[1].to_i : nil
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
