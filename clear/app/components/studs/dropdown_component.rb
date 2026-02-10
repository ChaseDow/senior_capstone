# frozen_string_literal: true

module Studs
  class DropdownComponent < ViewComponent::Base
    COLORS = {
      orange:  { base: "bg-orange-500", hover: "hover:bg-orange-600", ring: "focus-visible:ring-orange-300/70" },
      blue:    { base: "bg-blue-600",   hover: "hover:bg-blue-700",   ring: "focus-visible:ring-blue-300/70" },
      emerald: { base: "bg-emerald-600", hover: "hover:bg-emerald-700", ring: "focus-visible:ring-emerald-300/70" },
      zinc:    { base: "bg-zinc-800",   hover: "hover:bg-zinc-700",   ring: "focus-visible:ring-zinc-300/50" }
    }.freeze

    SIZES = {
      xs: { pad: "px-2.5 py-1.5", text: "text-xs",   radius: "rounded-lg",  width: "w-32" },
      sm: { pad: "px-3 py-2",     text: "text-sm",   radius: "rounded-xl",  width: "w-40" },
      md: { pad: "px-4 py-2.5",   text: "text-sm",   radius: "rounded-xl",  width: "w-48" },
      lg: { pad: "px-5 py-3",     text: "text-base", radius: "rounded-2xl", width: "w-56" }
    }.freeze

    def initialize(label:, items:, color: :zinc, size: :md, class_name: nil, name: "dropdown", selected_value: nil)
      @label = label
      @items = items
      @color = COLORS.key?(color) ? color : :zinc
      @size = SIZES.key?(size) ? size : :md
      @class_name = class_name
      @name = name
      @selected_value = selected_value
    end

    def button_classes
      c = COLORS.fetch(@color)
      s = SIZES.fetch(@size)
      [
        "inline-flex items-center justify-center font-medium text-white",
        "transition cursor-pointer",
        "focus:outline-none focus-visible:ring-2",
        s[:pad], s[:text], s[:radius], s[:width],
        c[:base], c[:hover], c[:ring],
        "disabled:opacity-50 disabled:cursor-not-allowed",
        @class_name
      ].compact.join(" ")
    end
  end
end
