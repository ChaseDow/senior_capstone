# frozen_string_literal: true

require "time"

module Syllabuses
  class MeetingInfoExtractor
    # Exclude obvious non-class meeting lines
    EXCLUDE = /(conference\s*times|by\s+appointment|zoom\s+meeting|meeting\s*id)/i

    # Things that should never be treated as the class location
    BAD_LOCATION_HINT = /(@|email\s*:|teaching\s+assistants?|instructor\s*:|professor\s*:|office\s*:|office\s*hours)/i

    # Extra office-hours filters (CSC 265 style)
    OFFICE_LIKE = /(office\s*hours|\boffice\b|\bappointments?\b)/i

    ROOM_HINT = /
      \b(
        [A-Z]{2,6}\s*\d{3} |                     # IESB 305, NH 140, WT 324
        [A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s+\d{3}   # Woodard Hall 215
      )\b
    /x

    # Supports:
    # - MWF, TR, MW, etc.
    # - Monday, Tuesday, Thursday
    # - Tue/Thu, Tues/Thurs, Mon/Wed/Fri, etc.
    DAYS = /
      (?<days>
        MWF|MW|WF|TR|TTH|TH|M|T|W|R|F|
        (?:Mon(?:day)?|Tue(?:s(?:day)?)?|Wed(?:nesday)?|Thu(?:r(?:s(?:day)?)?)?|Fri(?:day)?)
        (?:\s*\/\s*(?:Mon(?:day)?|Tue(?:s(?:day)?)?|Wed(?:nesday)?|Thu(?:r(?:s(?:day)?)?)?|Fri(?:day)?))*
      )
    /ix

    START_TIME = /
      (?<start>
        \d{1,2}
        (?:[:\.]\d{2})?
        \s*(?:A\.?\s*M\.?|P\.?\s*M\.?|AM|PM)?
      )
    /ix

    END_TIME = /
      (?<end>
        \d{1,2}
        (?:[:\.]\d{2})?
        \s*(?:A\.?\s*M\.?|P\.?\s*M\.?|AM|PM)?
      )
    /ix

    # Labels
    VENUE_LABEL        = /\AVenue:\s*(?<location>.+?)\s*\((?<rest>.+)\)\z/i
    LABELED_LINE       = /\A(?:Time\s*&\s*Room|Time\s*and\s*Room|Class\s*Time(?:\s*&\s*Room)?|Meeting\s*Time|When\s*&\s*Where)\s*:\s*(?<rest>.+)\z/i
    LOCATION_TIME_LINE = /\A(?:Location\s*&\s*Time|Location\s*and\s*Time)\s*:\s*(?<rest>.+)\z/i

    # days -> time -> location
    CORE = /\A#{DAYS}\s*[:\-]?\s*#{START_TIME}\s*(?:-|–|to)\s*#{END_TIME}\s+(?<location>.+)\z/i
    LABS = /\ALabs?:\s*#{DAYS}\s+#{START_TIME}\s*(?:-|–|to)\s*#{END_TIME}\s+(?:in\s+)?(?<location>.+)\z/i

    # location -> days -> time (Reverse Engineering style)
    LOCATION_FIRST = /\A(?<location>.+?)\s+#{DAYS}\s+#{START_TIME}\s*(?:-|–|to)\s*#{END_TIME}\b/i

    SECTION_SPLIT = /Section\s*\d+\s*:\s*/i

    def self.call(lines)
      candidates = build_candidates(lines)
      best = nil

      candidates.each do |raw|
        raw_norm = normalize(raw)
        next if raw_norm.blank?
        next if office_candidate?(raw_norm)   # <-- key fix for office hours
        next if raw_norm.match?(EXCLUDE)

        match_hash, kind = match_meeting(raw_norm)
        next unless match_hash

        confidence = score_candidate(raw_norm, match_hash, kind)
        payload    = build_payload(raw_norm, match_hash, confidence)

        best = payload if best.nil? || payload[:confidence] > best[:confidence]
      end

      best
    end

    def self.build_candidates(lines)
      header = lines.first(180)
      out = []

      header.each_with_index do |l, i|
        out << l
        out << "#{l} #{header[i + 1]}" if header[i + 1]
        out << "#{l} #{header[i + 1]} #{header[i + 2]}" if header[i + 1] && header[i + 2]
      end

      out.map { |s| normalize(s) }.uniq
    end

    # Prevent office hours from ever being treated as the class meeting.
    #
    # Examples to skip:
    # - "MW: 1:00 pm - 3:00 pm"
    # - "Office: IESB 216 MW 1:00 pm - 3:00 pm"
    # - "Office Hours: Tues/Thurs 1-3pm"
    def self.office_candidate?(s)
      s = normalize(s)
      return false if s.blank?

      return true if s.match?(/office\s*hours/i)
      return true if s.match?(/\Aoffice\s*:/i)
      return true if s.match?(/\bappointments?\b/i)

      # Starts with day-code + ":" + time range (classic office hours style)
      day_code = /\A(?:MWF|MW|WF|TR|TTH|TH|M|T|W|R|F)\s*:\s*/i
      return true if s.match?(day_code) && s.match?(START_TIME) && s.match?(END_TIME)

      # Contains "office" + has days + time range
      if s.match?(OFFICE_LIKE) && s.match?(DAYS) && s.match?(START_TIME) && s.match?(END_TIME)
        return true
      end

      false
    end

    def self.match_meeting(s)
      # 1) Venue style: "Venue: IESB 216 (Tues/Thurs 12-1:50 pm)"
      if (m = s.match(VENUE_LABEL))
        rest = normalize(m[:rest])
        if (core = rest.match(/\A#{DAYS}\s*[-–]?\s*#{START_TIME}\s*(?:-|–|to)\s*#{END_TIME}\z/i))
          return [
            { days: core[:days], start: core[:start], end: core[:end], location: m[:location] },
            :venue
          ]
        end
      end

      # 2) Labeled line
      if (m = s.match(LABELED_LINE))
        rest = normalize(m[:rest])

        if (core = rest.match(CORE))
          return [ to_hash(core), :labeled ]
        end

        if (lf = rest.match(LOCATION_FIRST))
          return [ to_hash(lf), :labeled_location_first ]
        end
      end

      # 3) Location & Time (with optional sections)
      if (m = s.match(LOCATION_TIME_LINE))
        rest = normalize(m[:rest])

        parts =
          if rest.match?(SECTION_SPLIT)
            rest.split(SECTION_SPLIT).map(&:strip).reject(&:blank?)
          else
            [ rest ]
          end

        parts.each do |part|
          part = normalize(part)

          if (lf = part.match(LOCATION_FIRST))
            return [ to_hash(lf), :location_time_section ]
          end

          if (core = part.match(CORE))
            return [ to_hash(core), :location_time_core ]
          end
        end
      end

      # 4) Labs
      if (m = s.match(LABS))
        return [ to_hash(m), :labs ]
      end

      # 5) Bare core
      if (m = s.match(CORE))
        return [ to_hash(m), :core ]
      end

      # 6) Bare location-first
      if (m = s.match(LOCATION_FIRST))
        return [ to_hash(m), :location_first ]
      end

      nil
    end

    def self.to_hash(match)
      {
        days: match[:days],
        start: match[:start],
        end: match[:end],
        location: match[:location]
      }
    end

    def self.score_candidate(raw, match_hash, kind)
      loc = match_hash[:location].to_s

      score = 0
      score += 35 if match_hash[:days].present?
      score += 35 if match_hash[:start].present? && match_hash[:end].present?

      # Prefer when the CAPTURED location itself looks like a room
      score += 30 if loc.match?(ROOM_HINT)

      # Still reward if the raw string contains a room (useful for messy captures)
      score += 10 if raw.match?(ROOM_HINT)

      # Prefer certain kinds
      score += 12 if kind == :labs
      score += 14 if kind == :venue
      score += 10 if %i[labeled location_time_section labeled_location_first].include?(kind)

      # Penalize "office" / appointments lines even if they slipped through
      score -= 60 if raw.match?(OFFICE_LIKE)

      # Penalize locations that obviously are not locations
      score -= 45 if loc.match?(BAD_LOCATION_HINT)

      score -= 40 if raw.match?(EXCLUDE)
      [ [ score, 0 ].max, 100 ].min
    end

    def self.build_payload(raw, match_hash, confidence)
      start_raw, end_raw = fix_suspicious_meridiem(match_hash[:start], match_hash[:end])
      start_raw, end_raw = unify_meridiem(start_raw, end_raw)

      start_hms = parse_time(start_raw)
      end_hms   = parse_time(end_raw)

      start_hms, end_hms = normalize_time_range(start_hms, end_hms)

      loc = normalize_location(match_hash[:location])
      loc = fix_location_from_raw(raw, loc)

      {
        meeting_days: normalize_days(match_hash[:days]),
        starts_at: start_hms,
        ends_at: end_hms,
        location: loc,
        meeting_raw: raw,
        confidence: confidence
      }.compact
    end

    # If start clearly AM and end says PM but would make a 10+ hour class, flip end to AM.
    def self.fix_suspicious_meridiem(start_raw, end_raw)
      s = normalize(start_raw).upcase
      e = normalize(end_raw).upcase
      return [ start_raw, end_raw ] if s.blank? || e.blank?

      if s.include?("AM") && e.include?("PM")
        start_hr = s[/\A(\d{1,2})/, 1].to_i
        end_hr   = e[/\A(\d{1,2})/, 1].to_i
        if start_hr.between?(7, 11) && end_hr.between?(8, 12)
          e = e.sub("PM", "AM")
          return [ start_raw, e ]
        end
      end

      [ start_raw, end_raw ]
    end

    # If only one side has AM/PM, copy it to the other side.
    def self.unify_meridiem(start_raw, end_raw)
      s = normalize(start_raw).upcase
      e = normalize(end_raw).upcase

      s_has = s.match?(/\bAM\b|\bPM\b|A\.?\s*M\.?|P\.?\s*M\.?/)
      e_has = e.match?(/\bAM\b|\bPM\b|A\.?\s*M\.?|P\.?\s*M\.?/)

      return [ start_raw, end_raw ] if s_has && e_has
      return [ start_raw, end_raw ] unless s_has ^ e_has

      mer =
        if e_has
          e.include?("A") && e.include?("M") ? "AM" : "PM"
        else
          s.include?("A") && s.include?("M") ? "AM" : "PM"
        end

      if !s_has && e_has
        [ "#{start_raw} #{mer}", end_raw ]
      else
        [ start_raw, "#{end_raw} #{mer}" ]
      end
    end

    # If end <= start, assume end is missing PM and add 12 hours.
    def self.normalize_time_range(start_hms, end_hms)
      return [ start_hms, end_hms ] if start_hms.blank? || end_hms.blank?

      s = hms_to_seconds(start_hms)
      e = hms_to_seconds(end_hms)

      e = (e + 12 * 3600) % (24 * 3600) if e <= s

      [ start_hms, seconds_to_hms(e) ]
    end

    def self.hms_to_seconds(hms)
      h, m, s = hms.split(":").map(&:to_i)
      (h * 3600) + (m * 60) + s
    end

    def self.seconds_to_hms(sec)
      h = sec / 3600
      sec %= 3600
      m = sec / 60
      s = sec % 60
      format("%02d:%02d:%02d", h, m, s)
    end

    def self.fix_location_from_raw(raw, loc)
      loc_s = loc.to_s
      return loc if loc_s.blank?

      if loc_s.match?(BAD_LOCATION_HINT) || loc_s.length > 60 || !loc_s.match?(ROOM_HINT)
        room = extract_primary_room(raw)
        return room if room.present?
      end

      loc
    end

    def self.extract_primary_room(raw)
      rooms = raw.to_s.scan(ROOM_HINT).map { |s| normalize_location(s) }.reject(&:blank?)
      rooms.first
    end

    def self.normalize(s)
      s.to_s
       .gsub("\u00A0", " ")
       .tr("\u2013\u2014\u2212", "-")
       .gsub(/[’‘`\\]/, "")
       .gsub(/\s+/, " ")
       .strip
    end

    # Convert many day formats into canonical MTWRF order, e.g. "Tues/Thurs" -> "TR"
    def self.normalize_days(raw)
      s = normalize(raw).downcase
      return nil if s.blank?

      # Fast path for letter codes
      if s.match?(/\b(mwf|mw|wf|tr|tth|th|m|t|w|r|f)\b/i)
        d = s.upcase.gsub(/\s+/, "")
        d = d.gsub("TTH", "TR").gsub("TH", "R")

        out = +""
        %w[M T W R F].each { |ch| out << ch if d.include?(ch) }
        return out.presence
      end

      # Word/slash formats
      letters = []
      letters << "M" if s.match?(/\bmon(day)?\b/)
      letters << "T" if s.match?(/\btue(s(day)?)?\b/)
      letters << "W" if s.match?(/\bwed(nesday)?\b/)
      letters << "R" if s.match?(/\bthu(r(s(day)?)?)?\b/)
      letters << "F" if s.match?(/\bfri(day)?\b/)

      letters.uniq!
      out = +""
      %w[M T W R F].each { |ch| out << ch if letters.include?(ch) }
      out.presence
    end

    def self.parse_time(raw)
      s = normalize(raw).upcase
      return nil if s.blank?

      s = s.gsub("A. M.", "AM").gsub("P. M.", "PM").gsub(/\s+/, " ")
      s = s.gsub(/\A(\d{1,2})\.(\d{2})/, '\1:\2') # 2.30pm -> 2:30pm

      formats = [ "%I:%M %p", "%I:%M%p", "%I %p", "%H:%M", "%H" ]
      t = formats.lazy.map { |f| Time.strptime(s, f) rescue nil }.find(&:itself)

      t&.strftime("%H:%M:%S")
    end

    def self.normalize_location(raw)
      loc = normalize(raw)
      loc = loc.sub(/\A(?:in|room|rm\.?)\s+/i, "")
      loc = loc.sub(/[.,;:]\z/, "")
      3.times { loc = loc.gsub(/(\d)\s+(\d)/, '\1\2') } # "IESB 21 6" -> "IESB 216"
      loc.presence
    end
  end
end
