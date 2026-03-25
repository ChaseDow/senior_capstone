# frozen_string_literal: true

class CalendarDraft < ApplicationRecord
  belongs_to :user

  # Operations format (model can be "event", "course", or "course_item"):
  #   create: { "type" => "create", "model" => "event"|"course"|"course_item", "temp_id" => "d_abc", "data" => {...} }
  #   update: { "type" => "update", "model" => "event"|"course"|"course_item", "id" => 42, "data" => {...} }
  #   delete: { "type" => "delete", "model" => "event"|"course"|"course_item", "id" => 42 }

  # Lightweight struct used to represent draft-created events in the calendar preview.
  # Must respond to the same interface that _calendar.html.erb expects from an Event.
  DraftEventProxy = Struct.new(
    :temp_id, :title, :starts_at, :ends_at, :color, :location, :description,
    keyword_init: true
  ) do
    def id = temp_id
    def model_name = Event.model_name
    def recurring = false

    def contrast_text_color
      Event.new(color: color.presence || "#34D399").contrast_text_color
    end
  end

  # Lightweight struct used to represent draft-created courses in the calendar preview.
  DraftCourseProxy = Struct.new(
    :temp_id, :title, :start_time, :end_time, :color, :location, :description,
    :professor, :repeat_days, :start_date, :end_date,
    keyword_init: true
  ) do
    def id = temp_id
    def model_name = Course.model_name

    def contrast_text_color
      Course.new(color: color.presence || "#34D399").contrast_text_color
    end
  end

  DraftCourseItemProxy = Struct.new(
    :temp_id, :title, :kind, :due_at, :details, :course, :color,
    keyword_init: true
  ) do
    def id = temp_id
    def model_name = CourseItem.model_name
    def starts_at = due_at
    def ends_at = due_at ? due_at + 30.minutes : nil

    def contrast_text_color
      course.respond_to?(:contrast_text_color) ? course.contrast_text_color : "#F9FAFB"
    end
  end

  # --------------------------------------------------------------------------
  # Mutation helpers
  # --------------------------------------------------------------------------

  def add_create(model, data)
    temp_id = "d_#{SecureRandom.hex(4)}"
    update!(operations: operations + [ {
      "type" => "create", "model" => model,
      "temp_id" => temp_id, "data" => data.stringify_keys
    } ])
    temp_id
  end

  def add_update(model, id, data)
    # Collapse repeated updates to the same record into a single entry
    filtered = operations.reject { |op| op["type"] == "update" && op["model"] == model && op["id"] == id }
    update!(operations: filtered + [ {
      "type" => "update", "model" => model, "id" => id, "data" => data.stringify_keys
    } ])
  end

  def add_delete(model, id)
    # Drop any pending update for this record, then queue the delete
    filtered = operations.reject { |op| op["model"] == model && op["id"] == id }
    update!(operations: filtered + [ { "type" => "delete", "model" => model, "id" => id } ])
  end

  # --------------------------------------------------------------------------
  # Apply / Discard
  # --------------------------------------------------------------------------

  def apply!(user)
    prev = operations.dup
    ActiveRecord::Base.transaction do
      operations.each do |op|
        case op["model"]
        when "event"
          case op["type"]
          when "create" then user.events.create!(op["data"].symbolize_keys)
          when "update" then user.events.find(op["id"]).update!(op["data"].symbolize_keys)
          when "delete" then user.events.find(op["id"]).destroy!
          end
        when "course"
          case op["type"]
          when "create" then user.courses.create!(op["data"].symbolize_keys)
          when "update" then user.courses.find(op["id"]).update!(op["data"].symbolize_keys)
          when "delete" then user.courses.find(op["id"]).destroy!
          end
        when "course_item"
          items = CourseItem.joins(:course).where(courses: { user_id: user.id })
          case op["type"]
          when "create"
            data = op["data"].symbolize_keys
            course = user.courses.find(data[:course_id])
            course.course_items.create!(data.except(:course_id))
          when "update" then items.find(op["id"]).update!(op["data"].symbolize_keys)
          when "delete" then items.find(op["id"]).destroy!
          end
        end
      end
    end
    update!(operations: [], previous_operations: prev)
  end

  def discard!
    update!(previous_operations: operations, operations: [])
  end

  def operation_count
    operations.size
  end

  # --------------------------------------------------------------------------
  # Preview: merge draft ops into a real occurrence list
  # --------------------------------------------------------------------------

  def build_preview_occurrences(occurrences, range_start, range_end)
    # ── Event draft ops ──
    event_deleted_ids = operations
      .select { |op| op["type"] == "delete" && op["model"] == "event" }
      .map { |op| op["id"] }

    event_update_ops = operations
      .select { |op| op["type"] == "update" && op["model"] == "event" }
      .index_by { |op| op["id"] }

    event_create_ops = operations.select { |op| op["type"] == "create" && op["model"] == "event" }

    # ── Course draft ops ──
    course_deleted_ids = operations
      .select { |op| op["type"] == "delete" && op["model"] == "course" }
      .map { |op| op["id"] }

    course_update_ops = operations
      .select { |op| op["type"] == "update" && op["model"] == "course" }
      .index_by { |op| op["id"] }

    course_create_ops = operations.select { |op| op["type"] == "create" && op["model"] == "course" }

    # ── Course item draft ops ──
    item_deleted_ids = operations
      .select { |op| op["type"] == "delete" && op["model"] == "course_item" }
      .map { |op| op["id"] }

    item_update_ops = operations
      .select { |op| op["type"] == "update" && op["model"] == "course_item" }
      .index_by { |op| op["id"] }

    item_create_ops = operations.select { |op| op["type"] == "create" && op["model"] == "course_item" }

    # Build updated objects once per record id, not once per occurrence
    updated_event_cache  = {}
    updated_course_cache = {}
    updated_item_cache   = {}

    result = occurrences.map do |occ|
      record = occ.respond_to?(:event) ? occ.event : occ
      model  = record.model_name.singular

      if model == "event"
        if event_deleted_ids.include?(record.id)
          next Event::Occurrence.new(
            event: record, starts_at: occ.starts_at, ends_at: occ.ends_at,
            draft_status: "deleted"
          )
        end

        if (update_op = event_update_ops[record.id])
          updated = updated_event_cache[record.id] ||= begin
            e = Event.new(record.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
            e.id = record.id
            e.instance_variable_set(:@new_record, false)
            e
          end

          if updated.recurring?
            occ_date      = occ.starts_at.to_date
            next if updated.starts_at.blank?
            next if updated.repeat_until.blank?
            next if occ_date < updated.starts_at.to_date || occ_date > updated.repeat_until
            next unless Array(updated.repeat_days).map(&:to_i).include?(occ_date.wday)

            new_time      = updated.starts_at.in_time_zone
            new_start     = Time.zone.local(occ_date.year, occ_date.month, occ_date.day,
                                            new_time.hour, new_time.min, new_time.sec)
            orig_duration = (record.ends_at && record.starts_at) ? (record.ends_at - record.starts_at) : nil
            new_duration  = (updated.ends_at && updated.starts_at) ? (updated.ends_at - updated.starts_at) : orig_duration
            new_end       = new_duration ? (new_start + new_duration) : nil

            next Event::Occurrence.new(event: updated, starts_at: new_start, ends_at: new_end, draft_status: "updated")
          else
            next Event::Occurrence.new(
              event: updated,
              starts_at: updated.starts_at || occ.starts_at,
              ends_at: updated.ends_at,
              draft_status: "updated"
            )
          end
        end

      elsif model == "course"
        if course_deleted_ids.include?(record.id)
          next Course::Occurrence.new(
            event: record, starts_at: occ.starts_at, ends_at: occ.ends_at,
            draft_status: "deleted"
          )
        end

        if (update_op = course_update_ops[record.id])
          updated = updated_course_cache[record.id] ||= begin
            c = Course.new(record.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
            c.id = record.id
            c.instance_variable_set(:@new_record, false)
            c
          end

          # Courses are always recurring — keep the occurrence calendar date,
          # update time-of-day and other attributes in the preview.
          occ_date  = occ.starts_at.to_date
          next if updated.start_date.blank? || updated.end_date.blank?
          next if occ_date < updated.start_date || occ_date > updated.end_date
          next unless Array(updated.repeat_days).map(&:to_i).include?(occ_date.wday)

          new_start = Time.zone.local(occ_date.year, occ_date.month, occ_date.day,
                                      updated.start_time.hour, updated.start_time.min, updated.start_time.sec)
          new_end   = if updated.end_time.present?
                        Time.zone.local(occ_date.year, occ_date.month, occ_date.day,
                                        updated.end_time.hour, updated.end_time.min, updated.end_time.sec)
          end

          next Course::Occurrence.new(event: updated, starts_at: new_start, ends_at: new_end, draft_status: "updated")
        end
      elsif model == "course_item"
        if item_deleted_ids.include?(record.id)
          next Event::Occurrence.new(
            event: record, starts_at: occ.starts_at, ends_at: occ.ends_at,
            draft_status: "deleted"
          )
        end

        if (update_op = item_update_ops[record.id])
          updated = updated_item_cache[record.id] ||= begin
            ci = CourseItem.new(record.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
            ci.id = record.id
            ci.course ||= user.courses.find_by(id: ci.course_id)
            ci.instance_variable_set(:@new_record, false)
            ci
          end

          start_at = updated.due_at || occ.starts_at
          next Event::Occurrence.new(
            event: updated,
            starts_at: start_at,
            ends_at: start_at ? (start_at + 30.minutes) : occ.ends_at,
            draft_status: "updated"
          )
        end
      end

      occ
    end.compact

    event_update_ops.each do |id, update_op|
      updated = updated_event_cache[id]
      unless updated
        source_event = user.events.find_by(id: id)
        next unless source_event

        updated = Event.new(source_event.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
        updated.id = source_event.id
        updated.instance_variable_set(:@new_record, false)
        updated_event_cache[id] = updated
      end

      next unless updated.recurring?

      updated.occurrences_between(range_start, range_end).each do |updated_occurrence|
        exists = result.any? do |occ|
          record = occ.respond_to?(:event) ? occ.event : occ
          record.model_name.singular == "event" &&
            record.id == updated.id &&
            occ.starts_at == updated_occurrence.starts_at &&
            occ.respond_to?(:draft_status) &&
            occ.draft_status == "updated"
        end
        next if exists

        result << Event::Occurrence.new(
          event: updated,
          starts_at: updated_occurrence.starts_at,
          ends_at: updated_occurrence.ends_at,
          draft_status: "updated"
        )
      end
    end

    item_update_ops.each do |id, update_op|
      updated = updated_item_cache[id]
      unless updated
        source_item = CourseItem.joins(:course).where(courses: { user_id: user.id }).find_by(id: id)
        next unless source_item

        updated = CourseItem.new(source_item.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
        updated.id = source_item.id
        updated.course ||= user.courses.find_by(id: updated.course_id)
        updated.instance_variable_set(:@new_record, false)
        updated_item_cache[id] = updated
      end

      next if updated.due_at.blank? || updated.due_at < range_start || updated.due_at > range_end

      exists = result.any? do |occ|
        record = occ.respond_to?(:event) ? occ.event : occ
        record.model_name.singular == "course_item" &&
          record.id == updated.id &&
          occ.respond_to?(:draft_status) &&
          occ.draft_status == "updated"
      end
      next if exists

      result << Event::Occurrence.new(
        event: updated,
        starts_at: updated.due_at,
        ends_at: updated.due_at + 30.minutes,
        draft_status: "updated"
      )
    end

    # ── Draft-created events ──
    event_create_ops.each do |op|
      data = op["data"].symbolize_keys
      starts_at = Time.zone.parse(data[:starts_at].to_s) rescue nil
      next unless starts_at

      ends_at = data[:ends_at].present? ? (Time.zone.parse(data[:ends_at].to_s) rescue nil) : nil
      duration_minutes = data[:duration_minutes].to_i if data[:duration_minutes].present?
      ends_at ||= (starts_at + duration_minutes.minutes) if ends_at.blank? && duration_minutes.present?
      recurring = Event.new(recurring: data[:recurring]).recurring?
      repeat_days = Array(data[:repeat_days]).reject(&:blank?).map(&:to_i)
      repeat_until = data[:repeat_until].present? ? (Date.parse(data[:repeat_until].to_s) rescue nil) : nil

      proxy = DraftEventProxy.new(
        temp_id: op["temp_id"],
        title: data[:title].presence || "(Draft Event)",
        starts_at: starts_at,
        ends_at: ends_at,
        color: data[:color].presence || "#34D399",
        location: data[:location],
        description: data[:description]
      )

      if recurring && repeat_days.any? && repeat_until.present?
        window_start = [ range_start.to_date, starts_at.to_date ].max
        window_end   = [ range_end.to_date, repeat_until ].min
        next if window_end < window_start

        start_time = starts_at.in_time_zone
        duration_seconds = ends_at.present? ? (ends_at - starts_at) : nil

        d = window_start
        while d <= window_end
          if repeat_days.include?(d.wday)
            occ_start = Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min, start_time.sec)
            occ_end   = duration_seconds.present? ? (occ_start + duration_seconds) : nil

            result << Event::Occurrence.new(
              event: proxy, starts_at: occ_start, ends_at: occ_end,
              draft_status: "created"
            )
          end
          d += 1.day
        end
      elsif starts_at >= range_start && starts_at <= range_end
        result << Event::Occurrence.new(
          event: proxy, starts_at: starts_at, ends_at: ends_at,
          draft_status: "created"
        )
      end
    end

    # ── Draft-created courses ──
    course_create_ops.each do |op|
      data = op["data"].symbolize_keys
      start_time = Time.zone.parse(data[:start_time].to_s) rescue nil
      next unless start_time

      end_time = data[:end_time].present? ? (Time.zone.parse(data[:end_time].to_s) rescue nil) : nil
      repeat_days = Array(data[:repeat_days]).reject(&:blank?).map(&:to_i)
      course_start = data[:start_date].present? ? (Date.parse(data[:start_date].to_s) rescue nil) : nil
      course_end   = data[:end_date].present? ? (Date.parse(data[:end_date].to_s) rescue nil) : nil

      proxy = DraftCourseProxy.new(
        temp_id: op["temp_id"],
        title: data[:title].presence || "(Draft Course)",
        start_time: start_time,
        end_time: end_time,
        color: data[:color].presence || "#34D399",
        location: data[:location],
        description: data[:description],
        professor: data[:professor],
        repeat_days: repeat_days,
        start_date: course_start,
        end_date: course_end
      )

      # Generate occurrences for the draft course within the visible range
      window_start = [ range_start.to_date, course_start ].compact.max
      window_end   = [ range_end.to_date, course_end ].compact.min
      next if window_end < window_start

      d = window_start
      while d <= window_end
        if repeat_days.include?(d.wday)
          occ_start = Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min, start_time.sec)
          occ_end   = end_time ? Time.zone.local(d.year, d.month, d.day, end_time.hour, end_time.min, end_time.sec) : nil

          result << Course::Occurrence.new(
            event: proxy, starts_at: occ_start, ends_at: occ_end,
            draft_status: "created"
          )
        end
        d += 1.day
      end
    end

    # ── Draft-created course items ──
    item_create_ops.each do |op|
      data = op["data"].symbolize_keys
      due_at = data[:due_at].present? ? (Time.zone.parse(data[:due_at].to_s) rescue nil) : nil
      next unless due_at && due_at >= range_start && due_at <= range_end

      course = user.courses.find_by(id: data[:course_id])
      proxy = DraftCourseItemProxy.new(
        temp_id: op["temp_id"],
        title: data[:title].presence || "(Draft Item)",
        kind: data[:kind].presence || "assignment",
        due_at: due_at,
        details: data[:details],
        course: course,
        color: course&.color || "#34D399"
      )

      result << Event::Occurrence.new(
        event: proxy, starts_at: due_at, ends_at: due_at + 30.minutes,
        draft_status: "created"
      )
    end

    result.sort_by(&:starts_at)
  end
end
