# frozen_string_literal: true

module Studs
  class AgendaComponent < ::ViewComponent::Base
    protected
    renders_many :items, "Studs::AgendaItemComponent"

    def initialize(title: "Agenda", subtitle: nil, mode: :panel, empty_message: "All of your scheduled events for today appear here`.", class_name: nil)
      @title = title
      @subtitle = subtitle
      @mode = mode
      @empty_message = empty_message
      @class_name = class_name
    end

    def wrapper_classes
      base = [
        "w-full rounded-2xl border border-zinc-800 bg-zinc-950/40",
        @mode.to_sym == :panel ? "h-full" : nil,
        @class_name
      ].compact.join(" ")

      base
    end
  end
end
