# frozen_string_literal: true

class UniversityCalendarController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!

  IMPORT_COLOR = "#60A5FA"

  def preview
    @items = UniversityCalendar::RssFetcher.call
    @existing_keys = existing_event_keys
  rescue => e
    redirect_to events_path, alert: "Could not load university calendar: #{e.message}"
  end

  def import
    items = UniversityCalendar::RssFetcher.call
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

    redirect_to events_path, notice: "Imported #{imported} event(s) from the university calendar. #{skipped} duplicate(s) skipped."
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
