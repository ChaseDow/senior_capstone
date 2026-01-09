# frozen_string_literal: true

module Studs
  class SecondaryButtonComponent < ::ViewComponent::Base
    COLORS = {
      zinc: {
        base: "border-zinc-700/70 text-zinc-200",
        hover: "hover:bg-zinc-900/60 hover:text-zinc-50",
        ring: "focus-visible:ring-zinc-300/40"
      },
      emerald: {
        base: "border-emerald-500/35 text-emerald-200",
        hover: "hover:bg-emerald-950/35 hover:text-emerald-100",
        ring: "focus-visible:ring-emerald-300/60"
      },
      blue: {
        base: "border-blue-500/35 text-blue-200",
        hover: "hover:bg-blue-950/35 hover:text-blue-100",
        ring: "focus-visible:ring-blue-300/60"
      },
      red: {
        base: "border-red-500/40 text-red-200",
        hover: "hover:bg-red-950/40 hover:text-red-100",
        ring: "focus-visible:ring-red-300/50"
      }
    }.freeze

    SIZES = {
      xs: "px-2.5 py-1.5 text-xs",
      sm: "px-3 py-2 text-sm",
      md: "px-4 py-2 text-sm",
      lg: "px-4 py-2.5 text-base"
    }.freeze

    def initialize(label:, path: nil, href: nil, color: :zinc, size: :md, type: "button", disabled: false, class_name: nil, **attrs)
      @label = label
      @href = href || path
      @color = COLORS.key?(color) ? color : :zinc
      @size = SIZES.key?(size) ? size : :md
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

      [
        "inline-flex items-center justify-center rounded-xl border",
        "transition cursor-pointer",
        "focus:outline-none focus-visible:ring-2",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        SIZES.fetch(@size),
        c[:base], c[:hover], c[:ring],
        @class_name
      ].compact.join(" ")
    end
  end
end
