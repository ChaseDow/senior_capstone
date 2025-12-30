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
      base = "flex items-center gap-3 rounded-xl px-3 py-2 text-sm transition"

      state =
        if @active
          "#{base} bg-zinc-800 text-orange-200"
        else
          "#{base} text-zinc-200 hover:bg-zinc-900 hover:text-zinc-50"
        end

      [ state, @class_name ].compact.join(" ")
    end
  end
end
