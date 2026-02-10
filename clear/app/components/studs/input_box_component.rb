# frozen_string_literal: true

module Studs
  class InputBoxComponent < ::ViewComponent::Base
    COLORS = {
      orange:  { text: "text-orange-200", border: "border-orange-500/30", hover: "hover:bg-orange-500/10", ring: "focus-visible:ring-orange-400/40" },
      blue:    { text: "text-blue-200",   border: "border-blue-500/30",   hover: "hover:bg-blue-500/10",   ring: "focus-visible:ring-blue-400/40" },
      emerald: { text: "text-emerald-200", border: "border-emerald-500/30", hover: "hover:bg-emerald-500/10", ring: "focus-visible:ring-emerald-400/40" },
      zinc:    { text: "text-zinc-200",   border: "border-zinc-700",      hover: "hover:bg-zinc-800/60",   ring: "focus-visible:ring-zinc-400/30" },
      red:     { text: "text-red-200",    border: "border-red-500/30",    hover: "hover:bg-red-500/10",    ring: "focus-visible:ring-red-400/40" }
    }.freeze

    SIZES = {
      xs: { classes: "px-2.5 py-1 text-xs rounded-lg" },
      sm: { classes: "px-3 py-1.5 text-sm rounded-xl" },
      md: { classes: "px-4 py-2 text-sm rounded-xl" },
      lg: { classes: "px-5 py-2.5 text-base rounded-2xl" }
    }.freeze

    def initialize(name:, value: nil, placeholder: nil, type: "text", color: :zinc, size: :md, class_name: nil, **attrs)
      @name = name
      @value = value
      @placeholder = placeholder
      @type = type
      @color = COLORS.key?(color) ? color : :zinc
      @size = SIZES.key?(size) ? size : :md
      @class_name = class_name
      @attrs = attrs
    end

    def input_classes
      c = COLORS.fetch(@color)
      s = SIZES.fetch(@size)

      [
        "w-full font-medium",
        "border bg-transparent",
        "transition",
        "focus:outline-none focus-visible:ring-2",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        s[:classes], c[:text], c[:border], c[:hover], c[:ring],
        @class_name
      ].compact.join(" ")
    end
  end
end
