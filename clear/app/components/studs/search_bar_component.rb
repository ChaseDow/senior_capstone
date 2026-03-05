# frozen_string_literal: true

module Studs
  class SearchBarComponent < ::ViewComponent::Base
    def initialize(name: "q", value: nil, placeholder: "Search…", class_name: nil, input_class_name: nil, **attrs)
      @name            = name
      @value           = value
      @placeholder     = placeholder
      @class_name      = class_name
      @input_class_name = input_class_name
      @attrs           = attrs
    end

    def wrapper_classes
      [ "relative", @class_name ].compact.join(" ")
    end

    def input_classes
      [
        "w-full rounded-xl border bg-zinc-900/50",
        "pl-10 pr-3 py-2 text-sm text-zinc-100 placeholder:text-zinc-500",
        "focus:outline-none focus:ring-2 transition-all",
        @input_class_name
      ].compact.join(" ")
    end

    def input_style
      "border-color: var(--studs-border); --tw-ring-color: var(--studs-accent);"
    end
  end
end
