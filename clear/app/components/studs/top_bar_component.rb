# frozen_string_literal: true

module Studs
  class TopBarComponent < ::ViewComponent::Base
    renders_one :left
    renders_one :actions

    def initialize(title: nil, subtitle: nil, class_name: nil)
      @title = title
      @subtitle = subtitle
      @class_name = class_name
    end

    def wrapper_classes
      [
        "sticky top-0 z-30 w-full border-b border-zinc-800 bg-zinc-950/80 backdrop-blur",
        @class_name
      ].compact.join(" ")
    end
  end
end
