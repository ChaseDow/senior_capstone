# frozen_string_literal: true

require "net/http"
require "uri"

module UniversityCalendar
  class RssFetcher
    def self.call(url)
      new(url).call
    end

    def initialize(url)
      @url = url
    end

    def call
      xml = fetch_feed
      parse_items(xml)
    end

    private

    def fetch_feed
      uri = URI(@url)
      response = Net::HTTP.get_response(uri)
      raise "Failed to fetch university calendar: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def parse_items(xml)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!

      doc.css("item").filter_map do |item|
        title = item.at_css("title")&.text&.strip
        next if title.blank?

        starts_at = parse_date(item, "startdate") ||
                    parse_date(item, "start") ||
                    parse_date(item, "date") ||
                    parse_date(item, "pubDate")
        next if starts_at.nil?

        ends_at = parse_date(item, "enddate") || parse_date(item, "end")
        # All-day end dates from calendar feeds are often exclusive (next day at midnight),
        # so if ends_at == midnight and > starts_at, keep as-is; otherwise nil it out if same as starts_at.
        ends_at = nil if ends_at.present? && ends_at <= starts_at

        description = strip_html(item.at_css("description")&.text)
        location    = item.at_css("location")&.text&.strip

        {
          title:       title,
          description: description.presence,
          location:    location.presence,
          starts_at:   starts_at,
          ends_at:     ends_at
        }.compact
      end
    end

    def parse_date(item, field)
      text = item.at_css(field)&.text&.strip
      return nil if text.blank?

      Time.zone.parse(text)
    rescue ArgumentError, TypeError
      nil
    end

    def strip_html(html)
      return nil if html.blank?

      Nokogiri::HTML.fragment(html).text.strip
    end
  end
end
