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

    def initialize(time:, title:, meta: nil, href: nil, tag: nil, tag_color: :zinc, icon_name: nil, class_name: nil)
      @time = time
      @title = title
      @meta = meta
      @href = href
      @tag = tag
      @tag_color = TAG_COLORS.key?(tag_color) ? tag_color : :zinc
      @icon_name = icon_name
      @class_name = class_name
    end

    def wrapper_tag = @href.present? ? :a : :div

    def wrapper_attrs
      base = {
        class: [
          "group flex items-start gap-3 rounded-xl border border-zinc-800 bg-zinc-900/40 px-3 py-3",
          "transition hover:bg-zinc-900/60",
          @href.present? ? "cursor-pointer" : nil,
          @class_name
        ].compact.join(" ")
      }

      @href.present? ? base.merge(href: @href) : base
    end

    def tag_classes
      [
        "inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-medium",
        TAG_COLORS.fetch(@tag_color)
      ].join(" ")
    end
  end
end
