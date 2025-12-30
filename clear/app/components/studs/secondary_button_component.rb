# frozen_string_literal: true

module Studs
  class SecondaryButtonComponent < ::ViewComponent::Base
    COLORS = {
      orange:  { text: "text-orange-200", border: "border-orange-500/30", hover: "hover:bg-orange-500/10", ring: "focus-visible:ring-orange-400/40" },
      blue:    { text: "text-blue-200",   border: "border-blue-500/30",   hover: "hover:bg-blue-500/10",   ring: "focus-visible:ring-blue-400/40" },
      emerald: { text: "text-emerald-200", border: "border-emerald-500/30", hover: "hover:bg-emerald-500/10", ring: "focus-visible:ring-emerald-400/40" },
      zinc:    { text: "text-zinc-200",   border: "border-zinc-700",      hover: "hover:bg-zinc-800/60",   ring: "focus-visible:ring-zinc-400/30" },
      red:     { text: "text-red-200",    border: "border-red-500/30",    hover: "hover:bg-red-500/10",    ring: "focus-visible:ring-red-400/40" }
    }.freeze

    SIZES = {
      xs: { pad: "px-2.5 py-1.5", text: "text-xs",  radius: "rounded-lg" },
      sm: { pad: "px-3 py-2",     text: "text-sm",  radius: "rounded-xl" },
      md: { pad: "px-4 py-2.5",   text: "text-sm",  radius: "rounded-xl" },
      lg: { pad: "px-5 py-3",     text: "text-base", radius: "rounded-2xl" }
    }.freeze

    def initialize(label:, color: :zinc, size: :md, href: nil, type: "button", disabled: false, class_name: nil, **attrs)
      @label = label
      @color = COLORS.key?(color) ? color : :zinc
      @size = SIZES.key?(size) ? size : :md
      @href = href
      @type = type
      @disabled = disabled
      @class_name = class_name
      @attrs = attrs
    end

    def tag_name = @href.present? ? :a : :button

    def html_options
      base = { class: classes }.merge(@attrs)

      if tag_name == :a
        base.merge(href: @href, role: "button", "aria-disabled": @disabled)
      else
        base.merge(type: @type, disabled: @disabled)
      end
    end

    def classes
      c = COLORS.fetch(@color)
      s = SIZES.fetch(@size)

      [
        "inline-flex items-center justify-center font-medium",
        "border bg-transparent",
        "transition",
        "focus:outline-none focus-visible:ring-2",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        s[:pad], s[:text], s[:radius],
        c[:text], c[:border], c[:hover], c[:ring],
        @class_name
      ].compact.join(" ")
    end
  end
end
