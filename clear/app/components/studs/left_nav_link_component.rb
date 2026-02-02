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
      base = "studs-nav-link"
      state = @active ? "is-active" : nil
      [ base, state, @class_name ].compact.join(" ")
    end

    def icon_classes
      [
        "studs-nav-icon",
        "shrink-0",
        "[&>svg]:h-5 [&>svg]:w-5",
        "[&>svg]:fill-none [&>svg]:stroke-current"
      ].join(" ")
    end
  end
end
