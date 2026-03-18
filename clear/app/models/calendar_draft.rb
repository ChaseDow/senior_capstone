# frozen_string_literal: true

class CalendarDraft < ApplicationRecord
  belongs_to :user

  # Operations format:
  #   create: { "type" => "create", "model" => "event", "temp_id" => "d_abc", "data" => {...} }
  #   update: { "type" => "update", "model" => "event", "id" => 42, "data" => {...} }
  #   delete: { "type" => "delete", "model" => "event", "id" => 42 }

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

  # --------------------------------------------------------------------------
  # Mutation helpers
  # --------------------------------------------------------------------------

  def add_create(model, data)
    temp_id = "d_#{SecureRandom.hex(4)}"
    update!(operations: operations + [{
      "type" => "create", "model" => model,
      "temp_id" => temp_id, "data" => data.stringify_keys
    }])
    temp_id
  end

  def add_update(model, id, data)
    # Collapse repeated updates to the same record into a single entry
    filtered = operations.reject { |op| op["type"] == "update" && op["model"] == model && op["id"] == id }
    update!(operations: filtered + [{
      "type" => "update", "model" => model, "id" => id, "data" => data.stringify_keys
    }])
  end

  def add_delete(model, id)
    # Drop any pending update for this record, then queue the delete
    filtered = operations.reject { |op| op["model"] == model && op["id"] == id }
    update!(operations: filtered + [{ "type" => "delete", "model" => model, "id" => id }])
  end

  # --------------------------------------------------------------------------
  # Apply / Discard
  # --------------------------------------------------------------------------

  def apply!(user)
    prev = operations.dup
    ActiveRecord::Base.transaction do
      operations.each do |op|
        next unless op["model"] == "event"

        case op["type"]
        when "create" then user.events.create!(op["data"].symbolize_keys)
        when "update" then user.events.find(op["id"]).update!(op["data"].symbolize_keys)
        when "delete" then user.events.find(op["id"]).destroy!
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
    deleted_ids = operations
      .select { |op| op["type"] == "delete" && op["model"] == "event" }
      .map { |op| op["id"] }

    update_ops = operations
      .select { |op| op["type"] == "update" && op["model"] == "event" }
      .index_by { |op| op["id"] }

    create_ops = operations.select { |op| op["type"] == "create" && op["model"] == "event" }

    # Build updated event objects once per event id, not once per occurrence
    updated_event_cache = {}

    result = occurrences.map do |occ|
      record = occ.respond_to?(:event) ? occ.event : occ
      next occ unless record.model_name.singular == "event"

      if deleted_ids.include?(record.id)
        next Event::Occurrence.new(
          event: record, starts_at: occ.starts_at, ends_at: occ.ends_at,
          draft_status: "deleted"
        )
      end

      if (update_op = update_ops[record.id])
        updated = updated_event_cache[record.id] ||= begin
          e = Event.new(record.attributes.except("id", "created_at", "updated_at").merge(update_op["data"]))
          e.id = record.id
          e.instance_variable_set(:@new_record, false)
          e
        end

        if record.recurring?
          # For recurring events keep the occurrence's calendar date; only
          # time-of-day and non-date attributes change in the preview.
          occ_date      = occ.starts_at.to_date
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

      occ
    end.compact

    create_ops.each do |op|
      data = op["data"].symbolize_keys
      starts_at = Time.zone.parse(data[:starts_at].to_s) rescue nil
      next unless starts_at
      next if starts_at < range_start || starts_at > range_end

      ends_at = data[:ends_at].present? ? (Time.zone.parse(data[:ends_at].to_s) rescue nil) : nil

      proxy = DraftEventProxy.new(
        temp_id: op["temp_id"],
        title: data[:title].presence || "(Draft Event)",
        starts_at: starts_at,
        ends_at: ends_at,
        color: data[:color].presence || "#34D399",
        location: data[:location],
        description: data[:description]
      )

      result << Event::Occurrence.new(
        event: proxy, starts_at: starts_at, ends_at: ends_at,
        draft_status: "created"
      )
    end

    result.sort_by(&:starts_at)
  end
end
