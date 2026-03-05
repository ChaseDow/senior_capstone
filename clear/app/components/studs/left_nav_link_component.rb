# frozen_string_literal: true

module Studs
  class LeftNavLinkComponent < ::ViewComponent::Base
    def initialize(label:, path:, icon_name: nil, active: false, class_name: nil)
      @label = label
      @path = path
      @icon_name = icon_name
      @active = active
      @class_name = class_name
    end

    def classes
      base = "group flex items-center gap-3 rounded-xl px-3 py-2 text-sm transition"

      state =
        if @active
          "#{base} bg-white/10 studs-nav-link--active"
        else
          "#{base} text-zinc-200 hover:bg-white/5 hover:text-zinc-50"
        end

      [ state, @class_name ].compact.join(" ")
    end

    def icon_classes
      svg_base = [
        "shrink-0",
        "[&>svg]:h-5 [&>svg]:w-5",
        "[&>svg]:opacity-90",
        "[&>svg]:fill-none [&>svg]:stroke-current"
      ].join(" ")

      color = @active ? "studs-icon--active" : "studs-icon--inactive group-hover:text-zinc-50"

      "#{svg_base} #{color}"
    end
  end
end
