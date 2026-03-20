# frozen_string_literal: true

require "date"

module Syllabuses
  class CourseItemsExtractor
    MONTHS = CourseAttributesExtractor::MONTHS

    MONTH_NAMES_RE = MONTHS.keys.map(&:capitalize).join("|")

    # Date patterns
    MONTH_DAY = /(?<month>#{MONTH_NAMES_RE}|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+(?<day>\d{1,2})/i
    NUMERIC_DATE = %r{(?<month>\d{1,2})/(?<day>\d{1,2})(?:/(?<year>\d{2,4}))?}
    OUTLINE_DATES_NUM = /\(?(?<month>\d{1,2})\/(?<days>\d{1,2}(?:,\d{1,2})*)\/(?<year>\d{4})\)?/
    PAREN_DATE = /\((\d{1,2}\/\d{1,2}(?:,\d{1,2})*\/\d{4})\)/

    # Strong deliverable patterns — these are unambiguous item labels.
    # They match lines that START with or are primarily about a deliverable.
    STRONG_PATTERNS = [
      [ /\bhw\s*\d+/i,                                    "assignment" ],
      [ /\bhomework\s*\d+/i,                              "assignment" ],
      [ /\bhomework\s*:/i,                                "assignment" ],
      [ /\bassignment\s*\d+/i,                            "assignment" ],
      [ /\bassignment\s*:/i,                              "assignment" ],
      [ /\bfinal\s+exam\b/i,                              "exam" ],
      [ /\bmidterm(\s+exam)?\b/i,                         "exam" ],
      [ /\bexam\s*\d+/i,                                  "exam" ],
      [ /\bexam\s*:/i,                                    "exam" ],
      [ /\btest\s*\d+/i,                                  "exam" ],
      [ /\bquiz\s*\d*/i,                                  "quiz" ],
      [ /\blab\s*\d+/i,                                   "lab" ],
      [ /\blab\s*:/i,                                     "lab" ],
      [ /\bfinal\s+project\b/i,                           "project" ],
      [ /\bproject\s*\d+/i,                               "project" ],
      [ /\bproject\s*(proposal|report|presentation)\b/i,  "project" ],
      [ /\bpresentation\s*\d*/i,                          "presentation" ],
      [ /\bseminar\s*\d+/i,                               "seminar" ],
      [ /\bpaper\s*\d+/i,                                 "assignment" ],
      [ /\bessay\s*\d+/i,                                 "assignment" ],
      [ /\breport\s*\d+/i,                                "assignment" ]
    ].freeze

    # Contextual patterns — only match if the line also contains "due" or a date.
    CONTEXTUAL_PATTERNS = [
      [ /\bhomework\b/i,      "assignment" ],
      [ /\bassignment\b/i,    "assignment" ],
      [ /\bproject\b/i,       "project" ],
      [ /\bpaper\b/i,         "assignment" ],
      [ /\bessay\b/i,         "assignment" ],
      [ /\breport\b/i,        "assignment" ],
      [ /\breading\b/i,       "reading" ],
      [ /\bseminar\b/i,       "seminar" ],
      [ /\blaboratory\b/i,    "lab" ],
      [ /\bpresentation\b/i,  "presentation" ]
    ].freeze

    SCHEDULE_HEADER = /\b(course\s+(schedule|outline)|tentative\s+(schedule|course\s+outline|outline)|class\s+schedule|course\s+calendar|weekly\s+schedule|schedule\s+of\s+(topics|assignments|events))\b/i

    SKIP_LINE = /\A\s*(page\s+\d|table\s+of\s+contents|\d+\s*$)/i
    BULLET_ONLY = /\A\s*•/

    # Lines that are clearly descriptive/structural, not deliverables
    DESCRIPTIVE_LINE = /\A\s*(course\s+(overview|structure|description|objectives|goals|policies)|grading|attendance|academic\s+integrity|disabilities|accommodations)/i

    ABBREV_MONTHS = {
      "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4,
      "may" => 5, "jun" => 6, "jul" => 7, "aug" => 8,
      "sep" => 9, "sept" => 9, "oct" => 10, "nov" => 11, "dec" => 12
    }.freeze

    # ----------------------------------------------------------------
    # Entry point
    # ----------------------------------------------------------------
    def self.call(text, term: nil)
      lines = normalize_lines(text)
      term_year = extract_term_year(term, text)

      items = []
      items.concat(extract_from_schedule_section(lines, term_year))
      items.concat(extract_from_date_lines(lines, term_year))

      items = deduplicate(items)
      items.sort_by { |i| i[:due_at] || "9999-12-31" }
    end

    # ----------------------------------------------------------------
    # Pass 1: Schedule section parsing
    # ----------------------------------------------------------------
    def self.extract_from_schedule_section(lines, term_year)
      items = []
      in_schedule = false
      schedule_lines = []

      lines.each do |line|
        if line.match?(SCHEDULE_HEADER)
          items.concat(parse_schedule_block(schedule_lines, term_year)) if schedule_lines.any?
          in_schedule = true
          schedule_lines = []
          next
        end

        if in_schedule
          schedule_lines << line
        end
      end

      items.concat(parse_schedule_block(schedule_lines, term_year)) if schedule_lines.any?
      items
    end

    def self.parse_schedule_block(lines, term_year)
      items = []
      current_date = nil

      lines.each do |line|
        next if line.strip.empty?
        next if line.match?(SKIP_LINE)
        next if line.match?(DESCRIPTIVE_LINE)

        date = parse_date_from_line(line, term_year)
        current_date = date if date

        next if line.match?(BULLET_ONLY)
        next if line.strip.match?(/\A\(?\d{1,2}\/\d{1,2}(?:,\d{1,2})*\/\d{4}\)?\z/)

        kind = detect_kind(line, has_date: current_date.present?)
        next unless kind

        title = extract_title(line, kind)
        next if title.blank?

        details = extract_details(line, title)

        items << {
          title: title,
          kind: kind,
          due_at: current_date&.to_s,
          details: details
        }
      end

      items
    end

    # ----------------------------------------------------------------
    # Pass 2: Date-anchored line scanning
    # ----------------------------------------------------------------
    def self.extract_from_date_lines(lines, term_year)
      items = []
      current_date = nil

      lines.each do |line|
        next if line.strip.empty?
        next if line.match?(SKIP_LINE)
        next if line.match?(DESCRIPTIVE_LINE)

        date = parse_date_from_line(line, term_year)
        current_date = date if date

        next if line.match?(BULLET_ONLY)

        kind = detect_kind(line, has_date: current_date.present?)
        next unless kind

        title = extract_title(line, kind)
        next if title.blank?

        details = extract_details(line, title)

        items << {
          title: title,
          kind: kind,
          due_at: current_date&.to_s,
          details: details
        }
      end

      items
    end

    # ----------------------------------------------------------------
    # Date parsing
    # ----------------------------------------------------------------
    def self.parse_date_from_line(line, term_year)
      if (m = line.match(OUTLINE_DATES_NUM))
        month_num = m[:month].to_i
        first_day = m[:days].split(",").first.to_i
        year = m[:year].to_i
        return safe_date(year, month_num, first_day)
      end

      if (m = line.match(MONTH_DAY))
        month_num = resolve_month(m[:month])
        day = m[:day].to_i
        year = term_year || infer_academic_year(month_num)
        return safe_date(year, month_num, day)
      end

      if (m = line.match(NUMERIC_DATE))
        month_num = m[:month].to_i
        day = m[:day].to_i
        year = if m[:year]
                 y = m[:year].to_i
                 y += 2000 if y < 100
                 y
               else
                 term_year || infer_academic_year(month_num)
               end
        return safe_date(year, month_num, day)
      end

      nil
    end

    def self.resolve_month(str)
      s = str.downcase.sub(/\.\z/, "")
      MONTHS[s] || ABBREV_MONTHS[s]
    end

    def self.safe_date(year, month, day)
      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end

    def self.extract_term_year(term, text)
      if term.present? && (m = term.match(/\b(20\d{2})\b/))
        return m[1].to_i
      end

      if (m = text.to_s.match(/\b(?:Spring|Summer|Fall|Winter)\s+(20\d{2})\b/i))
        return m[1].to_i
      end

      nil
    end

    def self.infer_academic_year(month)
      today = Date.today
      if today.month >= 8 && month.between?(1, 7)
        today.year + 1
      else
        today.year
      end
    end

    # ----------------------------------------------------------------
    # Kind detection — two-tier system
    #
    # Strong patterns always match (e.g., "HW01", "Midterm Exam", "Quiz 3").
    # Contextual patterns only match if the line also has "due" or a date
    # nearby, preventing false positives from descriptive text.
    # ----------------------------------------------------------------
    def self.detect_kind(line, has_date: false)
      # Strong patterns — unambiguous deliverable labels
      STRONG_PATTERNS.each do |pattern, kind|
        next unless line.match?(pattern)

        # Guard: "exam" inside "example"
        if kind == "exam" && line.match?(/\bexamples?\b/i) && !line.match?(/\bexam\s*\d|\bfinal\s+exam|\bmidterm/i)
          next
        end

        return kind
      end

      # Contextual patterns — only if line has "due" or a date is present
      line_has_due_context = has_date || line.match?(/\bdue\b/i)
      if line_has_due_context
        CONTEXTUAL_PATTERNS.each do |pattern, kind|
          return kind if line.match?(pattern)
        end
      end

      nil
    end

    # ----------------------------------------------------------------
    # Title extraction
    # ----------------------------------------------------------------
    def self.extract_title(line, kind)
      title = line.dup

      title = title.gsub(PAREN_DATE, "")
      title = title.sub(MONTH_DAY, "").sub(NUMERIC_DATE, "")

      title = title.sub(/\A\s*(week\s+\d+\s*[-:.]?\s*)/i, "")
      title = title.sub(/\A\s*\d+\s*[-:.]\s*/, "")
      title = title.sub(/\A\s*(due|due\s*date|deadline)\s*[:.-]\s*/i, "")

      title = title.sub(/\s*\(.*\)\s*\z/, "")

      title = title.sub(/\s*[-–]\s*\d+\s*(pts?|points?)\s*\z/i, "")
      title = title.sub(/\s*\d+\s*(pts?|points?)\s*\z/i, "")

      title = title.sub(/\A\s*[-–:,;.]\s*/, "")
      title = title.sub(/\s*[-–:,;.]\s*\z/, "")
      title = title.strip.squeeze(" ")

      title = title[0, 80].sub(/\s+\S*\z/, "") if title.length > 80

      title = kind.humanize if title.blank?

      title
    end

    # ----------------------------------------------------------------
    # Details extraction
    # ----------------------------------------------------------------
    def self.extract_details(line, title)
      details_parts = []

      line.scan(/\(([^)]+)\)/) do |cap|
        content = cap[0].strip
        next if content.match?(/\A\d{1,2}\/\d{1,2}(?:,\d{1,2})*\/\d{4}\z/)
        details_parts << content
      end

      if (m = line.match(/(\d+)\s*(pts?|points?)/i))
        details_parts << "#{m[1]} #{m[2]}"
      end

      if (m = line.match(/\b(ch(?:apter)?\.?\s*\d+(?:\s*[-–]\s*\d+)?)/i))
        details_parts << m[1]
      end

      details = details_parts.uniq.join("; ").strip
      details.presence
    end

    # ----------------------------------------------------------------
    # Deduplication
    # ----------------------------------------------------------------
    def self.deduplicate(items)
      seen = Set.new
      items.select do |item|
        key = "#{item[:title].downcase.strip}|#{item[:kind]}|#{item[:due_at]}"
        seen.add?(key)
      end
    end

    # ----------------------------------------------------------------
    # Utilities
    # ----------------------------------------------------------------
    def self.normalize_lines(text)
      text.to_s
          .gsub("\u00A0", " ")
          .tr("\u2013\u2014\u2212", "-")
          .lines
          .map { |l| l.strip.gsub(/\s+/, " ") }
          .reject(&:empty?)
    end
  end
end
