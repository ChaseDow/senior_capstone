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

    def initialize(
      time:,
      title:,
      meta: nil,
      href: nil,
      tag: nil,
      tag_color: :zinc,
      icon_name: nil,
      class_name: nil,

      # NEW (for the colored cards)
      accent_color: "#34D399",
      selected: false,

      # NEW (optional line like "9:00 AM – 10:30 AM • Event")
      subline: nil,

      **attrs
    )
      @time = time
      @title = title
      @meta = meta
      @href = href
      @tag = tag
      @tag_color = TAG_COLORS.key?(tag_color) ? tag_color : :zinc
      @icon_name = icon_name
      @class_name = class_name
      @attrs = attrs

      @accent_color = accent_color.presence || "#34D399"
      @selected = selected
      @subline = subline
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

    def tint_bg     = rgba(@accent_color, 0.14)
    def tint_hover  = rgba(@accent_color, 0.20)
    def tint_border = rgba(@accent_color, 0.35)
    def tint_bar    = rgba(@accent_color, 0.90)
    def open_bg     = rgba(@accent_color, 0.18)

def wrapper_attrs
  base_class = [
    "group block w-full rounded-2xl border p-3 transition cursor-pointer",
    (@selected ? "is-selected" : nil),
    @class_name,
    @attrs[:class]
  ].compact.join(" ")

  attrs = @attrs.dup
  attrs.delete(:class)

  {
    class: base_class,
    data: { agenda_item_card: true }.merge(@attrs.fetch(:data, {}))
  }.merge(attrs)
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