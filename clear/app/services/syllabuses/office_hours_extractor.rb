# frozen_string_literal: true

module Syllabuses
  # Extracts the professor's office location and office hours from syllabus text.
  # Returns a hash with :office and :office_hours keys (either may be nil).
  class OfficeHoursExtractor
    OFFICE_HOURS_LABEL = /\A\s*(?:office\s*hours|student\s*hours)\s*[:\-–—]?\s*(?<rest>.*)\z/i
    OFFICE_LABEL       = /(?:^|(?<=\s))office(?:\s*(?:location|room|number))?\s*[:\-–—]\s*(?<rest>.+)/i

    ROOM_HINT = /
      \b(
        [A-Z]{2,6}\s*\d{3,4}[A-Z]?   |           # IESB 216, WT 324, NH140
        (?:Room|Rm\.?)\s*\d{1,4}[A-Z]?  |        # Room 212
        [A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s+\d{3,4} # Woodard Hall 215
      )\b
    /x

    # A continuation line looks like it belongs to office hours if it starts with
    # a weekday or day-code and contains a time-like token.
    DAY_PREFIX = /\A(?:M(?:on(?:day)?)?|T(?:ue(?:s(?:day)?)?|h(?:u(?:r(?:s(?:day)?)?)?)?)?|W(?:ed(?:nesday)?)?|R|F(?:ri(?:day)?)?|Sat(?:urday)?|Sun(?:day)?|MWF|MW|TR|TTH|TH)\b/i
    TIME_HINT  = /\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)/i

    APPOINTMENT_HINT = /\b(by\s+appointment|appointments?\s+only)\b/i

    def self.call(text)
      lines = normalize_lines(text)

      office       = extract_office(lines)
      office_hours = extract_office_hours(lines)

      { office: office, office_hours: office_hours }.compact
    end

    # ---------------- helpers ----------------

    def self.normalize_lines(text)
      text.to_s
          .gsub("\u00A0", " ")
          .tr("\u2013\u2014\u2212", "-")
          .lines
          .map { |l| l.gsub(/[‘’`]/, "").gsub(/\s+/, " ").then { |t| collapse_spaced_headings(t) }.strip }
          .reject(&:empty?)
    end

    # --- office location ---------------------------------------------------

    def self.extract_office(lines)
      lines.each do |line|
        m = line.match(OFFICE_LABEL)
        next unless m

        # Make sure we matched "Office Number/Room/Location", not "Office Hours"
        prefix_end = m.begin(0)
        prefix = line[0...m.end(0)]
        next if prefix.match?(/office\s*hours/i)

        rest = m[:rest].to_s.strip
        next if rest.blank?

        # If the value contains "hours" it's really a merged line — skip.
        next if rest.match?(/\bhours?\b/i)

        # Strip trailing phone/email noise
        rest = rest.split(/\s{2,}|\s+\|\s+|\s+-\s+/).first.to_s.strip
        rest = rest.sub(/[.,;:]\z/, "")

        return rest.presence
      end

      nil
    end

    # --- office hours ------------------------------------------------------

    def self.extract_office_hours(lines)
      idx = lines.index { |l| l.match?(OFFICE_HOURS_LABEL) }
      return nil unless idx

      first_match = lines[idx].match(OFFICE_HOURS_LABEL)
      primary     = first_match[:rest].to_s.strip

      collected = []
      collected << primary if primary.present?

      # Walk forward and pick up continuation lines that look like
      # day/time entries (e.g. "Tuesday 10am-12pm") or appointment info.
      j = idx + 1
      while j < lines.length && j < idx + 6
        nxt = lines[j]
        break unless continuation_line?(nxt)
        collected << nxt
        j += 1
      end

      combined = collected.join("; ")
      combined = combined.gsub(/\s*;\s*/, "; ").gsub(/\s+/, " ").strip
      combined = combined.sub(/[.,;:]\z/, "")

      combined.presence
    end

    def self.continuation_line?(line)
      return false if line.blank?
      # Stop if the line starts a new labeled section.
      return false if line.match?(/\A[A-Z][A-Za-z ]{1,30}\s*:/) && !line.match?(DAY_PREFIX)

      (line.match?(DAY_PREFIX) && line.match?(TIME_HINT)) ||
        line.match?(APPOINTMENT_HINT)
    end

    def self.collapse_spaced_headings(s)
      s.gsub(/\b([B-HJ-Z]) ([A-Z]{2,})\b/) { "#{$1}#{$2}" }
    end
  end
end
