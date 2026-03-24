module AiTools
  class SystemInstructionBuilder
    def self.call(user:)
      name = user.email.split("@").first.gsub(/[._]/, " ").titleize

      # Gather upcoming events (next 14 days)
      upcoming_events = user.events
        .where("starts_at >= ? AND starts_at <= ?", Time.current, 14.days.from_now)
        .order(:starts_at)
        .limit(30)

      # Gather courses
      courses = user.courses.includes(:course_items)

      # Gather upcoming course items (next 14 days)
      upcoming_items = CourseItem
        .where(course: courses)
        .where("due_at >= ? AND due_at <= ?", Time.current, 14.days.from_now)
        .order(:due_at)
        .limit(30)

      parts = []
      parts << "You are a helpful academic assistant for a calendar and course management app called CLEAR."
      parts << "The user's name is #{name} (email: #{user.email}). Address them by their first name."
      parts << "Today's date is #{Date.today.strftime('%A, %B %d, %Y')}."

      if courses.any?
        course_lines = courses.map do |c|
          line = "- [ID:#{c.id}] #{c.title}"
          line += " (#{c.code})" if c.code.present?
          line += " with #{c.professor || c.instructor}" if c.professor.present? || c.instructor.present?
          line += ", #{c.meeting_days}" if c.meeting_days.present?
          line += " #{c.start_time&.strftime('%l:%M%P')}-#{c.end_time&.strftime('%l:%M%P')}" if c.start_time.present?
          line += " at #{c.location}" if c.location.present?
          line += " (#{c.term})" if c.term.present?
          line
        end
        parts << "\nThe user's courses:\n#{course_lines.join("\n")}"
      end

      if upcoming_events.any?
        event_lines = upcoming_events.map do |e|
          line = "- [ID:#{e.id}] #{e.title} on #{e.starts_at.strftime('%a %b %d at %l:%M%P')}"
          line += " at #{e.location}" if e.location.present?
          line += " — #{e.description}" if e.description.present?
          line
        end
        parts << "\nUpcoming events (next 14 days):\n#{event_lines.join("\n")}"
      end

      if upcoming_items.any?
        item_lines = upcoming_items.map do |ci|
          "- #{ci.display_title} due #{ci.due_at.strftime('%a %b %d at %l:%M%P')}"
        end
        parts << "\nUpcoming assignments & deadlines (next 14 days):\n#{item_lines.join("\n")}"
      end

      parts << "\nUse this context to give personalized advice, reminders, and insights. " \
               "You can suggest study strategies, flag busy days, warn about upcoming deadlines, " \
               "and help with time management. Keep responses concise and friendly."
       parts << "\nWhen the user wants to draft an event, use draft_event. They can create, edit, and delete using it with the event ID. " \
                "When the user wants to draft a course, use draft_course. They can create, edit, and delete using it with the course ID. " \
                "Each course and event listed above has an [ID:...] you can use. Draft-created records may return temporary IDs (temp_id). " \
                "Always confirm what was created or changed."

      parts.join("\n")
    end
  end
end
