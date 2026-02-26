# frozen_string_literal: true

module Studs
  class AgendaComponent < ::ViewComponent::Base
    renders_many :items, "Studs::AgendaItemComponent"

    def initialize(date: nil, title: "Agenda", subtitle: nil, count: nil, empty_message: "Nothing scheduled.", class_name: nil, mode: :panel, href: nil)
      @date = date
      @title = title
      @subtitle = subtitle
      @count = count
      @empty_message = empty_message
      @class_name = class_name
      @href = href
    end

    # currently not being used
    def agenda_count
      @count.presence || items.size
    end

    def subtitle_text
      return @subtitle if @subtitle.present?
      text = @date.strftime("%A, %B %-d")
      if agenda_count.positive?
        text += " • #{agenda_count} item#{"s" if agenda_count != 1}"
      end
      text
    end
  end
end
