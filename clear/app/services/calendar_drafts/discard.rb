# frozen_string_literal: true

module CalendarDrafts
  class Discard
    def self.call(draft)
      new(draft).call
    end

    def initialize(draft)
      @draft = draft
    end

    def call
      raise ActiveRecord::RecordInvalid, "Draft is not open" unless @draft.open?
      @draft.update!(status: :discarded, discarded_at: Time.current)
    end
  end
end
