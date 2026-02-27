# frozen_string_literal: true

module Studs
  class PrimaryButtonComponent < ::ViewComponent::Base
    COLORS = {
      orange:  { base: "bg-orange-500", hover: "hover:bg-orange-600", ring: "focus-visible:ring-orange-300/70" },
      blue:    { base: "bg-blue-600",   hover: "hover:bg-blue-700",   ring: "focus-visible:ring-blue-300/70" },
      emerald: { base: "bg-emerald-600", hover: "hover:bg-emerald-700", ring: "focus-visible:ring-emerald-300/70" },
      zinc:    { base: "bg-zinc-800",   hover: "hover:bg-zinc-700",   ring: "focus-visible:ring-zinc-300/50" },
      red:     { base: "bg-red-600",   hover: "hover:bg-red-700",   ring: "focus-visible:ring-red-300/70" }
    }.freeze

    def initialize(label:, color: :orange, href: nil, type: "button", disabled: false, class_name: nil, **attrs)
      @label = label
      @color = (COLORS.key?(color) ? color : :orange)
      @href = href
      @type = type
      @disabled = disabled
      @class_name = class_name
      @attrs = attrs
    end

    def tag_name = @href.present? ? :a : :button

    def html_options
      base = {
        class: classes
      }.merge(@attrs)

      if tag_name == :a
        base.merge(href: @href, role: "button", "aria-disabled": @disabled)
      else
        base.merge(type: @type, disabled: @disabled)
      end
    end

    def classes
      c = COLORS.fetch(@color)

      [
        "inline-flex items-center justify-center rounded-xl px-4 py-2 text-sm font-medium text-white",
        "transition cursor-pointer",
        "focus:outline-none focus-visible:ring-2",
        c[:base], c[:hover], c[:ring],
        "disabled:opacity-50 disabled:cursor-not-allowed",
        @class_name
      ].compact.join(" ")
    end
  end
end
