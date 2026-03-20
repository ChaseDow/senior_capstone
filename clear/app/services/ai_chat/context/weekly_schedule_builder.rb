# frozen_string_literal: true

module AiChat
  module Context
    class WeeklyScheduleBuilder
      MAX_ROWS = 60

      class << self
        def call(current_user:, max_rows: MAX_ROWS)
          week_start, week_end, range_start, range_end = week_window
          entries = schedule_entries(current_user: current_user, range_start: range_start, range_end: range_end)
            .sort_by { |entry| entry[:starts_at] }
            .first(max_rows)

          <<~CONTEXT
            You are CLEAR Assistant and your job is to answer user questions, explore scenarios with them, and ask what-if with their schedules when prompted.
            Schedule week window (not today's date): #{week_start.iso8601} to #{week_end.iso8601}.
            Weekly schedule snapshot (#{entries.size} items):
            #{entries.map { |entry| format_entry(entry) }.join("\n")}
          CONTEXT
        end

        private

        def week_window
          week_start = Date.current.beginning_of_week
          week_end = week_start + 6.days
          range_start = week_start.beginning_of_day
          range_end = week_end.end_of_day
          [ week_start, week_end, range_start, range_end ]
        end

        def schedule_entries(current_user:, range_start:, range_end:)
          week_start = range_start.to_date
          week_end = range_end.to_date

          event_rows = event_occurrences(current_user: current_user, range_start: range_start, range_end: range_end)
            .map { |entry| occurrence_to_entry(entry) }

          course_rows = course_occurrences(current_user: current_user, week_start: week_start, week_end: week_end, range_start: range_start, range_end: range_end)
            .map { |entry| occurrence_to_entry(entry) }

          event_rows + course_rows + course_item_rows(current_user: current_user, range_start: range_start, range_end: range_end)
        end

        def event_occurrences(current_user:, range_start:, range_end:)
          current_user.events
            .where("starts_at <= ?", range_end)
            .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
            .flat_map { |event| event.occurrences_between(range_start, range_end) }
        end

        def course_occurrences(current_user:, week_start:, week_end:, range_start:, range_end:)
          current_user.courses
            .where("start_date <= ?", week_end)
            .where("end_date >= ?", week_start)
            .flat_map { |course| course.occurrences_between(range_start, range_end) }
        end

        def course_item_rows(current_user:, range_start:, range_end:)
          CourseItem.joins(:course)
            .where(courses: { user_id: current_user.id })
            .where(due_at: range_start..range_end)
            .includes(:course)
            .map do |item|
              {
                model: "course_item",
                id: item.id,
                title: item.display_title,
                starts_at: item.due_at,
                ends_at: item.due_at
              }
            end
        end

        def occurrence_to_entry(entry)
          {
            model: entry.event.model_name.singular,
            id: entry.event.id,
            title: entry.event.title,
            starts_at: entry.starts_at,
            ends_at: entry.ends_at
          }
        end

        def format_entry(entry)
          start_at = entry[:starts_at].in_time_zone
          end_at = entry[:ends_at]
          time_part = if end_at.present?
            "#{start_at.strftime("%Y-%m-%d %H:%M")} to #{end_at.in_time_zone.strftime("%H:%M")}"
          else
            start_at.strftime("%Y-%m-%d %H:%M")
          end

          "- #{entry[:model]}: #{entry[:title]} (id: #{entry[:id]}) at #{time_part}"
        end
      end
    end
  end
end
