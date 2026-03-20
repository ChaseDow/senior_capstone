# frozen_string_literal: true

require "json"
require "ruby_llm"

module AiChat
  module Tooling
    class CalendarMutationTool < RubyLLM::Tool
      class UserFacingError < StandardError; end

      TOOL_NAME = "draft_mutate_calendar_item"
      SUPPORTED_MODELS = %w[event course course_item].freeze
      SUPPORTED_ACTIONS = %w[create update delete].freeze

      EVENT_FIELDS = %w[
        title starts_at ends_at duration_minutes location priority description color
        recurring repeat_days repeat_until
      ].freeze
      COURSE_FIELDS = %w[
        title code term color start_date end_date start_time end_time duration_minutes
        professor instructor location description repeat_days meeting_days
      ].freeze
      COURSE_ITEM_FIELDS = %w[title kind due_at details course_id].freeze
      SCORE_CODE_EXACT = 4
      SCORE_CODE_TOKEN = 2
      SCORE_TITLE_TOKEN = 1
      TOOL_CONTEXT_KEY = :ai_chat_calendar_mutation_tool_context
      MEETING_DAY_TO_WDAY = {
        "M" => 1,
        "T" => 2,
        "W" => 3,
        "R" => 4,
        "F" => 5
      }.freeze
      WDAY_TO_MEETING_DAY = MEETING_DAY_TO_WDAY.invert.freeze

      description "Draft-create, draft-update, or draft-delete events, courses, and course items."
      param :action
      param :model
      param :id
      param :title
      param :event_id
      param :event_title
      param :course_title
      param :course_code
      param :target_title
      param :from_title
      param :new_title
      param :rename_to
      param :attributes
      param :operations
      param :starts_at
      param :ends_at
      param :duration_minutes
      param :location
      param :priority
      param :description
      param :color
      param :recurring
      param :repeat_days
      param :repeat_until
      param :code
      param :term
      param :start_date
      param :end_date
      param :start_time
      param :end_time
      param :professor
      param :instructor
      param :meeting_days
      param :kind
      param :due_at
      param :details
      param :course_id

      def execute(**args)
        context = self.class.current_context
        self.class.call(
          args: args,
          user: context.fetch(:user),
          session: context.fetch(:session)
        )
      rescue KeyError
        "I couldn't complete that change right now. Please try again."
      rescue UserFacingError => e
        e.message
      rescue => e
        Rails.logger.error(
          "CalendarMutationTool execute error: #{e.class}: #{e.message} args=#{safe_debug_args(args).inspect}"
        )
        "I couldn't complete that change right now. Please try again with the item, date, and time."
      end

      class << self
        def with_context(user:, session:)
          previous = Thread.current[TOOL_CONTEXT_KEY]
          Thread.current[TOOL_CONTEXT_KEY] = { user: user, session: session }
          yield
        ensure
          Thread.current[TOOL_CONTEXT_KEY] = previous
        end

        def current_context
          Thread.current[TOOL_CONTEXT_KEY] || {}
        end

        def prompt_instructions
          <<~PROMPT
            Tool: #{TOOL_NAME}
            Use for calendar mutations (create/update/delete for events, courses, and course items).
            - action: create | update | delete
            - model: event | course | course_item
            - identify existing items by id/title when updating/deleting
            - provide model fields either as top-level args or in attributes
            - for event create, always include starts_at (for example: "tomorrow at 2 PM")
            For multiple changes in one request, use operations: [{action, model, ...}, ...].
          PROMPT
        end

        def call(args:, user:, session:)
          args = normalize_tool_args(args)
          draft = CalendarDraft.find_or_create_by!(user: user)
          session[:calendar_draft_mode] = true

          operations = args["operations"]
          if operations.is_a?(Array)
            return process_batch_operations!(operations: operations, user: user, draft: draft)
          end

          process_single_operation!(args: args, user: user, draft: draft)
        end

      private

      def safe_debug_args(args)
        args.to_h.deep_stringify_keys
      rescue
        { "_raw_args_class" => args.class.name }
      end

        def normalize_tool_args(raw_args)
          args = raw_args.to_h.deep_stringify_keys

          # Backward compatibility: older parser flow wrapped tool input in an `args` object.
          if args["args"].is_a?(Hash)
            nested = args.delete("args").deep_stringify_keys
            args = nested.merge(args)
          end

          args["attributes"] = normalize_json_hash(args["attributes"]) if args["attributes"].is_a?(String)
          args["operations"] = normalize_operations_payload(args["operations"])
          args
        end

        def normalize_operations_payload(value)
          case value
          when nil
            nil
          when String
            parsed = parse_json_value(value)
            normalize_operations_payload(parsed)
          when Array
            value.filter_map { |op| op.is_a?(Hash) ? op.deep_stringify_keys : nil }
          when Hash
            hash = value.deep_stringify_keys
            if hash.key?("action") || hash.key?("model")
              [ hash ]
            else
              hash.values.filter_map { |op| op.is_a?(Hash) ? op.deep_stringify_keys : nil }
            end
          else
            nil
          end
        end

        def normalize_json_hash(value)
          parsed = parse_json_value(value)
          parsed.is_a?(Hash) ? parsed.deep_stringify_keys : value
        end

        def parse_json_value(value)
          JSON.parse(value)
        rescue JSON::ParserError
          value
        end

        def normalize_action(action)
          value = action.to_s.strip
          SUPPORTED_ACTIONS.include?(value) ? value : nil
        end

        def normalize_model(model)
          value = model.to_s.strip
          SUPPORTED_MODELS.include?(value) ? value : nil
        end

        def process_batch_operations!(operations:, user:, draft:)
          valid_operations = operations.select { |op| op.is_a?(Hash) }
          fail_user!("I couldn't understand the batch request format.") if valid_operations.empty?

          results = valid_operations.map.with_index(1) do |operation_args, index|
            begin
              process_single_operation!(args: operation_args, user: user, draft: draft)
            rescue UserFacingError => e
              "Operation #{index}: #{e.message}"
            end
          end

          results.join("\n")
        end

        def process_single_operation!(args:, user:, draft:)
          action = normalize_action(args["action"])
          fail_user!("I couldn't tell which action you want. Please use create, update, or delete.") unless action

          model = normalize_model(args["model"])
          fail_user!("I couldn't tell what item type you meant. Please use event, course, or course item.") unless model

          case action
          when "create"
            create_in_draft!(model: model, args: args, user: user, draft: draft)
          when "update"
            update_in_draft!(model: model, args: args, user: user, draft: draft)
          when "delete"
            delete_in_draft!(model: model, args: args, user: user, draft: draft)
          end
        end

        def normalized_attributes(args)
          attrs = args["attributes"]
          out = if attrs.is_a?(Hash)
            attrs.stringify_keys
          else
            args.except("action", "model", "id", "title", "event_id", "event_title", "course_title", "target_title", "from_title")
                .stringify_keys
          end

          # Handle rename-style payloads where model may emit alias keys.
          out["title"] ||= args["new_title"].presence || args["rename_to"].presence
          out["title"] ||= args["title"].to_s.strip if args["action"].to_s == "create"
          out
        end

        def create_in_draft!(model:, args:, user:, draft:)
          attrs = normalized_attributes(args)

          case model
          when "event"
            payload = normalize_event_attributes(attrs)
            fail_user!("I need the event date and time before I can create it. Tell me when it starts (for example: \"tomorrow at 2 PM\").") if payload["starts_at"].blank?
            draft.add_create("event", payload)
            "Draft created: event \"#{payload["title"] || "(Untitled)"}\". Review in Dashboard and click Apply Draft."
          when "course"
            payload = normalize_course_attributes(attrs)
            draft.add_create("course", payload)
            "Draft created: course \"#{payload["title"] || "(Untitled)"}\". Review in Dashboard and click Apply Draft."
          when "course_item"
            course = resolve_course_for_course_item!(user: user, attrs: attrs, args: args)
            payload = normalize_course_item_attributes(attrs).merge("course_id" => course.id)
            draft.add_create("course_item", payload)
            "Draft created: course item \"#{payload["title"] || "(Untitled)"}\" for course \"#{course.title}\". Review in Dashboard and click Apply Draft."
          end
        end

        def update_in_draft!(model:, args:, user:, draft:)
          attrs = normalized_attributes(args)
          if (draft_create = find_draft_create_target(draft: draft, model: model, args: args, allow_implicit_recent: false))
            return update_draft_create!(model: model, draft: draft, draft_create: draft_create, attrs: attrs, user: user)
          end

          record = find_record(user: user, model: model, args: args)
          fail_user!(record_not_found_message(user: user, model: model, args: args)) unless record

          case model
          when "event"
            payload = normalize_event_attributes(attrs, existing: record)
            draft.add_update("event", record.id, payload)
            "Draft updated: event \"#{record.title}\". Review in Dashboard and click Apply Draft."
          when "course"
            payload = normalize_course_attributes(attrs, existing: record)
            draft.add_update("course", record.id, payload)
            "Draft updated: course \"#{record.title}\". Review in Dashboard and click Apply Draft."
          when "course_item"
            payload = normalize_course_item_attributes(attrs, existing: record)
            if payload["course_id"].present?
              target_course = user.courses.find_by(id: payload["course_id"].to_i)
              fail_user!("I couldn't move that item to the selected course because the course was not found.") unless target_course
            end
            draft.add_update("course_item", record.id, payload)
            "Draft updated: course item \"#{record.title}\". Review in Dashboard and click Apply Draft."
          end
        end

        def update_draft_create!(model:, draft:, draft_create:, attrs:, user:)
          existing_data = draft_create["data"].to_h

          payload = case model
          when "event"
            normalize_event_attributes(attrs, existing: draft_existing_record(model: model, data: existing_data))
          when "course"
            normalize_course_attributes(attrs, existing: draft_existing_record(model: model, data: existing_data))
          when "course_item"
            normalized = normalize_course_item_attributes(attrs, existing: draft_existing_record(model: model, data: existing_data))
            if normalized["course_id"].present?
              target_course = user.courses.find_by(id: normalized["course_id"].to_i)
              fail_user!("I couldn't move that item to the selected course because the course was not found.") unless target_course
            end
            normalized
          end

          merged_data = existing_data.merge(payload)
          updated_operations = draft.operations.map do |op|
            if op.equal?(draft_create)
              op.merge("data" => merged_data)
            else
              op
            end
          end
          draft.update!(operations: updated_operations)

          title = merged_data["title"].presence || existing_data["title"].presence || "(Untitled)"
          "Draft updated: #{model.humanize.downcase} \"#{title}\". Review in Dashboard and click Apply Draft."
        end

        def delete_in_draft!(model:, args:, user:, draft:)
          if (draft_create = find_draft_create_target(draft: draft, model: model, args: args, allow_implicit_recent: true))
            remove_draft_create!(draft: draft, model: model, draft_create: draft_create)
            return "Draft removed: #{model.humanize.downcase} \"#{draft_create.dig("data", "title").presence || "(Untitled)"}\"."
          end

          record = find_record(user: user, model: model, args: args)
          fail_user!(record_not_found_message(user: user, model: model, args: args)) unless record

          draft.add_delete(model, record.id)
          "Draft delete queued: #{model.humanize.downcase} \"#{record.title}\". Review in Dashboard and click Apply Draft."
        end

        def find_draft_create_target(draft:, model:, args:, allow_implicit_recent:)
          create_ops = draft.operations.select { |op| op["type"] == "create" && op["model"] == model }
          return nil if create_ops.empty?

          requested_id = (args["id"].presence || args["event_id"].presence).to_s.strip
          if requested_id.present?
            matched = create_ops.reverse.find { |op| op["temp_id"].to_s == requested_id }
            return matched if matched
          end

          requested_title = draft_target_title(args)
          if requested_title.present?
            normalized = requested_title.downcase
            matched = create_ops.reverse.find do |op|
              op.dig("data", "title").to_s.downcase.include?(normalized)
            end
            return matched if matched
          end

          # For delete intents like "remove it", default to latest draft create.
          allow_implicit_recent ? create_ops.last : nil
        end

        def draft_target_title(args)
          explicit_target = args["from_title"].presence || args["target_title"].presence || args["event_title"].presence
          return explicit_target.to_s.strip if explicit_target.present?

          raw_title = args["title"].to_s.strip
          return "" if raw_title.blank?

          # If top-level title matches attributes.title, treat it as the new title, not a lookup target.
          attrs_title = args.dig("attributes", "title").to_s.strip
          return "" if attrs_title.present? && raw_title.casecmp?(attrs_title)

          raw_title
        end

        def remove_draft_create!(draft:, model:, draft_create:)
          temp_id = draft_create["temp_id"].to_s

          filtered = draft.operations.reject do |op|
            next true if op.equal?(draft_create)

            op["model"] == model && op["id"].to_s == temp_id
          end
          draft.update!(operations: filtered)
        end

        def draft_existing_record(model:, data:)
          case model
          when "event"
            Event.new(
              starts_at: parse_time_safely(data["starts_at"]),
              ends_at: parse_time_safely(data["ends_at"])
            )
          when "course"
            Course.new(
              start_date: parse_date_safely(data["start_date"]),
              start_time: parse_time_safely(data["start_time"]),
              end_time: parse_time_safely(data["end_time"])
            )
          when "course_item"
            CourseItem.new(due_at: parse_time_safely(data["due_at"]))
          end
        end

        def parse_time_safely(value)
          return nil if value.blank?

          Time.zone.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def parse_date_safely(value)
          return nil if value.blank?

          Date.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def find_record(user:, model:, args:)
          id = args["id"].presence || args["event_id"].presence
          title = args["title"].presence || args["event_title"].presence

          case model
          when "event"
            return user.events.find_by(id: id.to_i) if id.present?
            find_by_title(user.events, title, time_column: :starts_at)
          when "course"
            return user.courses.find_by(id: id.to_i) if id.present?
            find_by_title(user.courses, title, time_column: :start_date)
          when "course_item"
            scope = CourseItem.joins(:course).where(courses: { user_id: user.id })
            return scope.find_by(id: id.to_i) if id.present?
            find_by_title(scope, title, time_column: :due_at)
          end
        end

        def find_by_title(scope, title, time_column:)
          normalized = title.to_s.strip
          return nil if normalized.blank?

          exact_match = scope.where("LOWER(title) = ?", normalized.downcase).order(time_column).first
          return exact_match if exact_match

          partial_matches = scope.where("title ILIKE ?", "%#{normalized}%").order(time_column).limit(2).to_a
          return partial_matches.first if partial_matches.one?

          nil
        end

        def find_course_by_title(user:, title:)
          user.courses.where("title ILIKE ?", "%#{title}%").order(:start_date).first
        end

        def resolve_course_for_course_item!(user:, attrs:, args:)
          course = resolve_explicit_course_for_course_item(user: user, attrs: attrs, args: args)
          return course if course

          course = infer_course_for_course_item(user: user, attrs: attrs, args: args)
          return course if course

          fail_user!(course_not_found_message(user: user, attrs: attrs, args: args))
        end

        def resolve_explicit_course_for_course_item(user:, attrs:, args:)
          course_id = attrs["course_id"].presence
          if course_id.present?
            course = user.courses.find_by(id: course_id.to_i)
            fail_user!("I couldn't find that course id in your schedule.") unless course
            return course
          end

          course_code = course_code_from(attrs: attrs, args: args)
          if course_code.present?
            course = user.courses.where("code ILIKE ?", "%#{course_code}%").order(:start_date).first
            return course if course
          end

          title = args["course_title"].to_s.strip
          return nil if title.blank?

          course = find_course_by_title(user: user, title: title)
          fail_user!(course_not_found_message(user: user, attrs: attrs, args: args)) unless course

          course
        end

        def infer_course_for_course_item(user:, attrs:, args:)
          from_code = infer_course_by_code_fragment(user: user, attrs: attrs, args: args)
          return from_code if from_code

          infer_course_by_title_tokens(user: user, attrs: attrs)
        end

        def course_code_from(attrs:, args:)
          attrs["course_code"].presence || args["course_code"].to_s.strip.presence
        end

        def infer_course_by_code_fragment(user:, attrs:, args:)
          code = course_code_from(attrs: attrs, args: args)
          return nil if code.blank?

          user.courses.where("code ILIKE ?", "%#{code}%").order(:start_date).first
        end

        def infer_course_by_title_tokens(user:, attrs:)
          item_title = attrs["title"].to_s.downcase.strip
          return nil if item_title.blank?

          scored_courses = user.courses.filter_map do |course|
            score = course_title_match_score(course: course, item_title: item_title)
            next if score <= 0

            [ course, score ]
          end
          return nil if scored_courses.empty?

          best_score = scored_courses.max_by { |(_, score)| score }[1]
          winners = scored_courses.select { |(_, score)| score == best_score }
          return nil unless winners.one?

          winners.first[0]
        end

        def course_title_match_score(course:, item_title:)
          score = 0

          course_code = course.code.to_s.downcase.strip
          if course_code.present?
            score += SCORE_CODE_EXACT if item_title.match?(/\b#{Regexp.escape(course_code)}\b/i)

            course_code.scan(/[a-z0-9]+/).uniq.each do |token|
              next if token.length < 3

              score += SCORE_CODE_TOKEN if item_title.match?(/\b#{Regexp.escape(token)}\b/i)
            end
          end

          course.title.to_s.downcase.scan(/[a-z0-9]+/).uniq.each do |token|
            next if token.length < 3

            score += SCORE_TITLE_TOKEN if item_title.match?(/\b#{Regexp.escape(token)}\b/i)
          end

          score
        end

        def record_not_found_message(user:, model:, args:)
          query = args["title"].presence || args["event_title"].presence
          label = model.tr("_", " ")
          suggestions = suggestions_for_model(user: user, model: model, query: query)

          if suggestions.any?
            "I couldn't find that #{label}. Did you mean: #{suggestions.join(", ")}?"
          elsif query.present?
            "I couldn't find a #{label} matching \"#{query}\". Please share the exact title."
          else
            "I couldn't find that #{label}. Please share the title so I can match it."
          end
        end

        def course_not_found_message(user:, attrs:, args:)
          query = args["course_title"].presence || course_code_from(attrs: attrs, args: args) || attrs["title"].to_s.strip
          suggestions = suggested_course_names(user: user, query: query)

          if suggestions.any?
            "I couldn't find a matching course for \"#{query}\". Did you mean: #{suggestions.join(", ")}?"
          else
            "I couldn't find a matching course for that request. Tell me the course name or code, or I can create it as an event instead."
          end
        end

        def suggestions_for_model(user:, model:, query:)
          return [] if query.blank?

          scope = model_scope(user: user, model: model)
          scope.where("title ILIKE ?", "%#{query.to_s.strip}%")
            .limit(3)
            .pluck(:title)
            .uniq
        end

        def suggested_course_names(user:, query:)
          normalized_query = query.to_s.downcase.strip
          return [] if normalized_query.blank?

          scored = user.courses.filter_map do |course|
            score = course_title_match_score(course: course, item_title: normalized_query)
            next if score <= 0

            [ course, score ]
          end

          scored.sort_by { |(_, score)| -score }
            .first(3)
            .map { |(course, _)| format_course_suggestion(course) }
            .uniq
        end

        def format_course_suggestion(course)
          code = course.code.to_s.strip
          code.present? ? "\"#{course.title}\" (#{code})" : "\"#{course.title}\""
        end

        def model_scope(user:, model:)
          case model
          when "event" then user.events
          when "course" then user.courses
          when "course_item" then CourseItem.joins(:course).where(courses: { user_id: user.id })
          else
            Course.none
          end
        end

        def fail_user!(message)
          raise UserFacingError, message
        end

        def normalize_event_attributes(attrs, existing: nil)
          out = attrs.slice(*EVENT_FIELDS)
          out["starts_at"] = parse_time!(out["starts_at"], default_time_from: existing&.starts_at)&.iso8601 if out.key?("starts_at")
          out["ends_at"] = parse_time!(out["ends_at"], default_time_from: existing&.ends_at)&.iso8601 if out.key?("ends_at")
          out["repeat_until"] = parse_date!(out["repeat_until"])&.iso8601 if out.key?("repeat_until")
          out["duration_minutes"] = out["duration_minutes"].to_i if out.key?("duration_minutes")
          out["priority"] = out["priority"].to_i if out.key?("priority")
          out["recurring"] = ActiveModel::Type::Boolean.new.cast(out["recurring"]) if out.key?("recurring")
          out["repeat_days"] = normalize_repeat_days(out["repeat_days"]) if out.key?("repeat_days")
          out.compact
        end

        def normalize_course_attributes(attrs, existing: nil)
          out = attrs.slice(*COURSE_FIELDS)
          out["start_date"] = parse_date!(out["start_date"])&.iso8601 if out.key?("start_date")
          out["end_date"] = parse_date!(out["end_date"])&.iso8601 if out.key?("end_date")
          out["start_time"] = parse_time!(out["start_time"], default_time_from: combine_date_and_time(existing&.start_date, existing&.start_time))&.iso8601 if out.key?("start_time")
          out["end_time"] = parse_time!(out["end_time"], default_time_from: combine_date_and_time(existing&.start_date, existing&.end_time))&.iso8601 if out.key?("end_time")
          out["duration_minutes"] = out["duration_minutes"].to_i if out.key?("duration_minutes")

          if out.key?("meeting_days")
            out["meeting_days"] = normalize_meeting_days(out["meeting_days"])
            out["repeat_days"] = repeat_days_from_meeting_days(out["meeting_days"]) unless out.key?("repeat_days")
          end

          if out.key?("repeat_days")
            out["repeat_days"] = normalize_repeat_days(out["repeat_days"])
            out["meeting_days"] = meeting_days_from_repeat_days(out["repeat_days"]) unless out.key?("meeting_days")
          end

          out.compact
        end

        def normalize_course_item_attributes(attrs, existing: nil)
          out = attrs.slice(*COURSE_ITEM_FIELDS)
          out["due_at"] = parse_time!(out["due_at"], default_time_from: existing&.due_at)&.iso8601 if out.key?("due_at")
          out["course_id"] = out["course_id"].to_i if out.key?("course_id")
          if out.key?("kind")
            kind = out["kind"].to_s
            out["kind"] = if CourseItem.kinds.key?(kind)
              kind
            elsif kind.match?(/\A\d+\z/)
              CourseItem.kinds.key(kind.to_i) || kind
            else
              kind
            end
          end
          out.compact
        end

        def normalize_repeat_days(value)
          Array(value).map(&:to_i).uniq.sort
        end

        def normalize_meeting_days(value)
          value.to_s.upcase.gsub(/[^MTWRF]/, "")
        end

        def repeat_days_from_meeting_days(value)
          value.to_s.chars.filter_map { |ch| MEETING_DAY_TO_WDAY[ch] }.uniq.sort
        end

        def meeting_days_from_repeat_days(value)
          Array(value).map(&:to_i).filter_map { |day| WDAY_TO_MEETING_DAY[day] }.join
        end

        def parse_time!(value, default_time_from: nil)
          return nil if value.blank?

          raw = value.to_s.strip
          raw_date = relative_date_keyword(raw)
          date_only = date_without_time_input?(raw)

          parsed = if time_only_input?(raw) && default_time_from.present?
            parsed_time = Time.zone.parse(raw)
            if parsed_time
              source = default_time_from.in_time_zone
              Time.zone.local(source.year, source.month, source.day, parsed_time.hour, parsed_time.min, parsed_time.sec)
            end
          elsif raw_date && default_time_from.present?
            source = default_time_from.in_time_zone
            Time.zone.local(raw_date.year, raw_date.month, raw_date.day, source.hour, source.min, source.sec)
          elsif raw_date
            fail_user!("I understood the date (#{raw_date.iso8601}), but I need a time too. What time should I use?")
          elsif date_only && default_time_from.present?
            date = Date.parse(raw)
            source = default_time_from.in_time_zone
            Time.zone.local(date.year, date.month, date.day, source.hour, source.min, source.sec)
          elsif date_only
            date = Date.parse(raw)
            fail_user!("I understood the date (#{date.iso8601}), but I need a time too. What time should I use?")
          else
            Time.zone.parse(raw)
          end

          fail_user!("I couldn't understand the date/time \"#{value}\". Try a format like \"March 24 at 2:00 PM\".") if parsed.nil?
          parsed
        end

        def parse_date!(value)
          return nil if value.blank?

          raw = value.to_s.strip
          return relative_date_keyword(raw) if relative_date_keyword(raw)

          Date.parse(raw)
        rescue ArgumentError
          fail_user!("I couldn't understand the date \"#{value}\". Try a format like \"2026-03-24\".")
        end

        def time_only_input?(raw)
          raw.match?(/\A\s*(\d{1,2})(:\d{2})?\s*(am|pm)?\s*\z/i)
        end

        def date_without_time_input?(raw)
          return false if raw.blank?
          return false if raw.match?(/\b\d{1,2}:\d{2}\b/i)
          return false if raw.match?(/\b\d{1,2}\s*(am|pm)\b/i)
          return false if raw.match?(/\b(noon|midnight)\b/i)
          return false if time_only_input?(raw)

          Date.parse(raw)
          true
        rescue ArgumentError
          false
        end

        def relative_date_keyword(raw)
          case raw.to_s.downcase.strip
          when "today" then Date.current
          when "tomorrow" then Date.current + 1.day
          when "yesterday" then Date.current - 1.day
          end
        end

        def combine_date_and_time(date, time_value)
          return nil if date.blank? || time_value.blank?

          source = time_value.in_time_zone
          Time.zone.local(date.year, date.month, date.day, source.hour, source.min, source.sec)
        end
      end
    end
  end
end
