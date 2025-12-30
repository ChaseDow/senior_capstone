# frozen_string_literal: true

module Studs
  class LeftNavComponent < ::ViewComponent::Base
    def initialize(brand: "Clear", items:, class_name: nil)
      @brand = brand
      @items = items
      @class_name = class_name
    end

    private

    def active_item?(item)
      path = item[:path].to_s
      return false if path.blank?

      current_page?(path) || request.path.start_with?(path)
    end

    def item_classes(active)
      base = "flex items-center gap-3 rounded-xl px-3 py-2 text-sm transition"
      if active
        "#{base} bg-zinc-800 text-orange-200"
      else
        "#{base} text-zinc-200 hover:bg-zinc-900 hover:text-zinc-50"
      end
    end

    def wrapper_classes
      [
        "h-screen w-64 shrink-0 border-r border-zinc-800 bg-zinc-950",
        @class_name
      ].compact.join(" ")
    end
  end
end
