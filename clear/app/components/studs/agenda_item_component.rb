# frozen_string_literal: true

module Studs
  class AgendaItemComponent < ::ViewComponent::Base
    TAG_COLORS = {
      zinc:    "bg-zinc-800 text-zinc-200 border-zinc-700",
      orange:  "bg-orange-500/10 text-orange-200 border-orange-500/20",
      blue:    "bg-blue-500/10 text-blue-200 border-blue-500/20",
      emerald: "bg-emerald-500/10 text-emerald-200 border-emerald-500/20",
      red:     "bg-red-500/10 text-red-200 border-red-500/20"
    }.freeze

    def initialize(time:, title:, meta: nil, href: nil, tag: nil, tag_color: :zinc, color: "#34D399", **attrs)
      @time = time
      @title = title
      @meta = meta
      @href = href
      @tag = tag
      @tag_color = TAG_COLORS.key?(tag_color) ? tag_color : :zinc
      @attrs = attrs
      @color = color
    end

    def wrapper_tag = @href.present? ? :a : :div

    def rgba(hex, alpha)
      h = hex.to_s.delete("#")
      return "rgba(52,211,153,#{alpha})" unless h.match?(/\A[\da-fA-F]{6}\z/)

      r = h[0..1].to_i(16)
      g = h[2..3].to_i(16)
      b = h[4..5].to_i(16)
      "rgba(#{r},#{g},#{b},#{alpha})"
    end

    def tint_bg     = rgba(@color, 0.14)
    def tint_hover  = rgba(@color, 0.20)
    def tint_border = rgba(@color, 0.35)
    def tint_bar    = rgba(@color, 0.90)
    def open_bg     = rgba(@color, 0.18)

    def wrapper_attrs
      base = {
        class: [
          "group rounded-2xl border p-3 transition cursor-pointer",
          @class_name
        ].compact.join(" ")
      }.merge(@attrs)
      @href.present? ? base.merge(href: @href) : base
    end

    def merged_style
      base_style = [
        "--bg-normal: #{tint_bg}",
        "--bg-hover: #{tint_hover}",
        "background-color: var(--bg-normal)",
        "border-color: #{tint_border}",
        "border-left: 6px solid #{tint_bar}"
      ].join("; ")

      existing = @attrs[:style].to_s.strip
      existing.present? ? "#{existing}; #{base_style}" : base_style
    end

    def tag_classes
      [
        "inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-medium",
        TAG_COLORS.fetch(@tag_color)
      ].join(" ")
    end
  end
end
