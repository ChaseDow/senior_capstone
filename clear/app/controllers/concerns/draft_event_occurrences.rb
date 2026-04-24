# frozen_string_literal: true

# This concern exists so that way code isn't duplicated on the Event and Draft Controllers
module DraftEventOccurrences
  extend ActiveSupport::Concern

  private

  def draft_event_occurrences_for(draft)
    base_items = current_user.events.order(starts_at: :asc).map do |event|
      Event::Occurrence.new(event: event, starts_at: event.starts_at, ends_at: event.ends_at)
    end
    return base_items if draft.blank? || draft.operation_count.zero?

    event_delete_ops = {}
    event_update_ops = {}
    event_create_ops = []

    draft.operations.each_with_index do |op, idx|
      next unless op["model"] == "event"

      case op["type"]
      when "delete"
        event_delete_ops[op["id"].to_i] = idx if op["id"].present?
      when "update"
        event_update_ops[op["id"].to_i] = [ op, idx ] if op["id"].present?
      when "create"
        event_create_ops << [ op, idx ] if op["temp_id"].present?
      end
    end

    updated_event_cache = {}
    items = base_items.map do |occ|
      event = occ.event

      if (delete_idx = event_delete_ops[event.id.to_i])
        next Event::Occurrence.new(
          event: event,
          starts_at: occ.starts_at,
          ends_at: occ.ends_at,
          draft_status: "deleted",
          draft_change_index: delete_idx
        )
      end

      update_op, update_idx = event_update_ops[event.id.to_i]
      if update_op.present?
        updated = updated_event_cache[event.id] ||= begin
          attrs = event.attributes.except("id", "created_at", "updated_at").merge(update_op["data"] || {})
          e = Event.new(attrs)
          e.id = event.id
          e.instance_variable_set(:@new_record, false)
          e
        end

        next Event::Occurrence.new(
          event: updated,
          starts_at: updated.starts_at || occ.starts_at,
          ends_at: updated.ends_at,
          draft_status: "updated",
          draft_change_index: update_idx
        )
      end

      occ
    end

    event_create_ops.each do |op, create_idx|
      data = (op["data"] || {}).symbolize_keys
      recurring = ActiveModel::Type::Boolean.new.cast(data[:recurring])
      starts_at = Time.zone.parse(data[:starts_at].to_s) rescue nil
      next unless starts_at

      ends_at = data[:ends_at].present? ? (Time.zone.parse(data[:ends_at].to_s) rescue nil) : nil
      repeat_days = Array(data[:repeat_days]).reject(&:blank?).map(&:to_i)
      repeat_until = data[:repeat_until].present? ? (Date.parse(data[:repeat_until].to_s) rescue nil) : nil
      proxy = CalendarDraft::DraftEventProxy.new(
        temp_id: op["temp_id"],
        title: data[:title].presence || "(Draft Event)",
        starts_at: starts_at,
        ends_at: ends_at,
        color: data[:color].presence || "#34D399",
        location: data[:location],
        description: data[:description],
        priority: data[:priority],
        recurring: recurring,
        repeat_days: repeat_days,
        repeat_until: repeat_until
      )

      items << Event::Occurrence.new(
        event: proxy,
        starts_at: starts_at,
        ends_at: ends_at,
        draft_status: "created",
        draft_change_index: create_idx
      )
    end

    items.sort_by!(&:starts_at)
    created_project_temp_ids = draft.operations.filter_map do |op|
      next unless op["type"] == "create" && op["model"] == "event" && op["temp_id"].present?
      next unless op["data"] && op["data"]["project_id"].present?

      op["temp_id"].to_s
    end.index_with(true)

    items.reject do |occ|
      event = occ.respond_to?(:event) ? occ.event : occ
      event.model_name.singular != "event" ||
        (event.respond_to?(:project_id) && event.project_id.present? && occ.respond_to?(:draft_status) && occ.draft_status.present?) ||
        (occ.respond_to?(:draft_status) && occ.draft_status == "created" && created_project_temp_ids[event.id.to_s])
    end
  end

  # For preserving the search filter on draft mode for Events
  def filter_index_items(items, query)
    q = query.to_s.downcase
    items.select { |occ| occ.event.title.to_s.downcase.include?(q) }
  end
end
