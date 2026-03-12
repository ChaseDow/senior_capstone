# frozen_string_literal: true

class UniversityCalendarController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!

  IMPORT_COLOR = "#60A5FA"

  def preview
    @rss_url = params[:rss_url].to_s.strip
    return unless @rss_url.present?

    @items = UniversityCalendar::RssFetcher.call(@rss_url)
    @existing_keys = existing_event_keys
  rescue => e
    flash.now[:alert] = "Could not load calendar feed: #{e.message}"
    @items = []
    @existing_keys = Set.new
  end

  def import
    @rss_url = params[:rss_url].to_s.strip
    items = UniversityCalendar::RssFetcher.call(@rss_url)
    existing = existing_event_keys

    imported = 0
    skipped  = 0

    items.each do |item|
      key = event_key(item[:title], item[:starts_at])

      if existing.include?(key)
        skipped += 1
        next
      end

      current_user.events.create!(
        title:       item[:title],
        description: item[:description],
        location:    item[:location],
        starts_at:   item[:starts_at],
        ends_at:     item[:ends_at],
        color:       IMPORT_COLOR
      )
      imported += 1
    end

    redirect_to events_path, notice: "Imported #{imported} event(s) from the calendar feed. #{skipped} duplicate(s) skipped."
  rescue => e
    redirect_to events_path, alert: "Import failed: #{e.message}"
  end

  private

  def existing_event_keys
    current_user.events.pluck(:title, :starts_at).map do |title, starts_at|
      event_key(title, starts_at)
    end.to_set
  end

  # Deduplicate by title + date (ignoring time-of-day differences for all-day events)
  def event_key(title, starts_at)
    "#{title.to_s.downcase.strip}|#{starts_at&.to_date}"
  end
end
