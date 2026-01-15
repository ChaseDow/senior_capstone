# frozen_string_literal: true

class Event < ApplicationRecord
  private

  def ends_at_after_starts_at
    return if ends_at >= starts_at
end
