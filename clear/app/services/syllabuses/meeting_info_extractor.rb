# frozen_string_literal: true

require "time"

module Syllabuses
  class MeetingInfoExtractor
    EXCLUDE = /(office\s*hours|conference\s*times|by\s+appointment|zoom\s+meeting|meeting\s*id)/i

    ROOM_HINT = /
      \b(
        [A-Z]{2,6}\s*\d{3} |                     # IESB 305, NH 140, WT 324
        [A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s+\d{3}   # Woodard Hall 215
      )\b
    /x

    DAYS = /
      (?<days>
        MWF|MW|WF|TR|TTH|TH|M|T|W|R|F|
        Monday|Tuesday|Wednesday|Thursday|Friday
      )
    /ix

    # Build two distinct named time captures so we can read :start and :end safely
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

    # “Venue: NH 140 (TR – 10:00 am to 11:50 am)”
    VENUE = /\AVenue:\s*(?<location>.+?)\s*\((?<rest>.+)\)\z/i

    # “Time & Room: TR 10:00 - 11:50 IESB 216”
    LABELED = /\A(?:Time\s*&\s*Room|Time\s*and\s*Room|Class\s*Time(?:\s*&\s*Room)?|Meeting\s*Time|When\s*&\s*Where)\s*:\s*(?<rest>.+)\z/i

    # Core meeting format
    CORE = /\A#{DAYS}\s*[:\-]?\s*#{START_TIME}\s*(?:-|–|to)\s*#{END_TIME}\s+(?<location>.+)\z/i

    # Lab style: “Labs: Thursday 2.30pm – 7pm in IESB 305.”
    LABS = /\ALabs?:\s*#{DAYS}\s+#{START_TIME}\s*(?:-|–|to)\s*#{END_TIME}\s+(?:in\s+)?(?<location>.+)\z/i

    def self.call(lines)
      candidates = build_candidates(lines)

      best = nil

      candidates.each do |raw|
        raw_norm = normalize(raw)
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
      header = lines.first(160) # meeting info usually early
      out = []

      header.each_with_index do |l, i|
        out << l
        out << "#{l} #{header[i + 1]}" if header[i + 1]
        out << "#{l} #{header[i + 1]} #{header[i + 2]}" if header[i + 1] && header[i + 2]
      end

      out.map { |s| normalize(s) }.uniq
    end

    def self.match_meeting(s)
      # 1) Venue style
      if (m = s.match(VENUE))
        rest = normalize(m[:rest])
        if (core = rest.match(/\A#{DAYS}\s*[-–]?\s*#{START_TIME}\s*(?:-|–|to)\s*#{END_TIME}\z/i))
          return [
            {
              days: core[:days],
              start: core[:start],
              end: core[:end],
              location: m[:location]
            },
            :venue
          ]
        end
      end

      # 2) Labeled style
      if (m = s.match(LABELED))
        rest = normalize(m[:rest])
        if (core = rest.match(CORE))
          return [ to_hash(core), :labeled ]
        end
      end

      # 3) Labs style
      if (m = s.match(LABS))
        return [ to_hash(m), :labs ]
      end

      # 4) Bare core
      if (m = s.match(CORE))
        return [ to_hash(m), :core ]
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
      score = 0
      score += 35 if match_hash[:days].present?
      score += 35 if match_hash[:start].present? && match_hash[:end].present?
      score += 20 if raw.match?(ROOM_HINT) || match_hash[:location].to_s.match?(ROOM_HINT)
      score += 10 if kind == :venue || kind == :labeled
      score -= 40 if raw.match?(EXCLUDE)
      [ [ score, 0 ].max, 100 ].min
    end

    def self.build_payload(raw, match_hash, confidence)
      {
        meeting_days: normalize_days(match_hash[:days]),
        starts_at: parse_time(match_hash[:start]),
        ends_at: parse_time(match_hash[:end]),
        location: normalize_location(match_hash[:location]),
        meeting_raw: raw,
        confidence: confidence
      }
    end

    def self.normalize(s)
      s.to_s
       .gsub("\u00A0", " ")
       .tr("\u2013\u2014\u2212", "-")
       .gsub(/[’‘`\\]/, "")
       .gsub(/\s+/, " ")
       .strip
    end

    def self.normalize_days(raw)
      d = raw.to_s.strip.downcase
      return "TR" if d == "tth" || d == "tuesday thursday"
      return "R"  if d == "th"
      return "M"  if d == "monday"
      return "T"  if d == "tuesday"
      return "W"  if d == "wednesday"
      return "R"  if d == "thursday"
      return "F"  if d == "friday"
      d.upcase
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
      3.times { loc = loc.gsub(/(\d)\s+(\d)/, '\1\2') } # "IESB 21 6" -> "IESB 216"
      loc.presence
    end
  end
end
