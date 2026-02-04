# frozen_string_literal: true

class Studs::TopBarComponent < ViewComponent::Base
  renders_one :leading
  renders_one :actions

  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end
end
