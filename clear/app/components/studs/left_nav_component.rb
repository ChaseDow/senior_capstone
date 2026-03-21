# frozen_string_literal: true

class Studs::LeftNavComponent < ViewComponent::Base
  def initialize(brand: nil, items:, settings_items: [], class_name: nil)
    @brand = brand
    @items = items
    @settings_items = settings_items
    @class_name = class_name
  end

  private

  def current_user
    helpers.current_user rescue nil
  end

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
      "group/link flex items-center gap-3 rounded-xl px-3 py-2.5 " \
      "text-sm font-medium transition-all duration-200 relative overflow-hidden " \
      "group-data-[collapsed=true]/sidebar:justify-center " \
      "group-data-[collapsed=true]/sidebar:px-2"

    if active
      "#{base} studs-nav-link--active-pill text-white"
    else
      "#{base} text-zinc-400 hover:text-zinc-100 hover:bg-white/5"
    end
  end

  def icon_classes(active)
    if active
      "studs-icon--active"
    else
      "studs-icon--inactive group-hover/link:text-zinc-100"
    end
  end

  def user_initials
    user = current_user
    return "?" unless user
    name = user.try(:name) || user.try(:first_name) || user.email
    name.to_s.strip.split(/\s+/).map { |w| w[0] }.first(2).join.upcase
  end

  def user_display_name
    user = current_user
    return "" unless user
    user.try(:name) || user.try(:first_name) || user.email.to_s.split("@").first
  end
end
