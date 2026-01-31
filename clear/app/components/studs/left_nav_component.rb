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

      return current_page?(path) if path == "/"
      current_page?(path) || request.path.start_with?(path)
    end

    def wrapper_classes
      [
        "studs-left-nav h-full w-64 shrink-0",
        @class_name
      ].compact.join(" ")
    end
  end
end
