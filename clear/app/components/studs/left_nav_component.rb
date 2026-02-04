# frozen_string_literal: true

class Studs::LeftNavComponent < ViewComponent::Base
  def initialize(brand: nil, items:, class_name: nil)
    @brand = brand
    @items = items
    @class_name = class_name
  end

  private

  def current_path
    helpers.request.path
  end

  def active_path?(path)
    path = path.to_s
    cur  = current_path

    return true if path == "/dashboard" && cur == "/"

    return true if cur == path

    return false if path == "/"
    cur.start_with?("#{path}/")
  end

  def link_classes(active)
    base =
      "group flex items-center gap-3 rounded-xl px-3 py-2.5 " \
      "text-base font-medium transition " \
      "group-data-[collapsed=true]/sidebar:justify-center " \
      "group-data-[collapsed=true]/sidebar:px-2"

    if active
      "#{base} bg-white/10 text-zinc-50"
    else
      "#{base} text-zinc-200 hover:bg-white/5 hover:text-zinc-50"
    end
  end

  def icon_classes(active)
    if active
      "text-emerald-300"
    else
      "text-zinc-200 group-hover:text-zinc-50"
    end
  end
end
