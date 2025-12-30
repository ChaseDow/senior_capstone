# frozen_string_literal: true

module IconHelper
  ICONS_ROOT = Rails.root.join("app/assets/icons").freeze

  # Usage:
  #   <%= icon "search-01-stroke-rounded", library: "huge_icons", class: "h-6 w-6 text-orange-400" %>
  #
  # Looks for:
  #   app/assets/icons/<library>/<name>.svg
  #
  # Accessibility:
  # - If you pass label: "Search", we set aria-label and leave it visible to screen readers.
  # - If you don't pass label:, we default to aria-hidden="true" (decorative icon).
  def icon(name, library: "huge_icons", label: nil, title: nil, **attrs)
    filename = normalize_icon_filename(name)
    path = ICONS_ROOT.join(library.to_s, filename)

    unless path.exist?
      return missing_icon_fallback(library, filename) unless Rails.env.development? || Rails.env.test?
      raise ArgumentError, "Icon not found: #{library}/#{filename} (expected at #{path})"
    end

    svg = read_svg(path)

    # Merge class passed like: icon(..., class: "h-6 w-6 text-orange-400")
    class_value = attrs.delete(:class)
    class_value = "h-5 w-5" if class_value.blank?

    attrs = normalize_svg_attrs(attrs, class_value:, label:, title:)

    inject_svg_opening_tag(svg, attrs).html_safe
  end

  private

  def normalize_icon_filename(name)
    base = name.to_s.strip
    base = base.delete_suffix(".svg")
    "#{base.tr('_', '-')}.svg"
  end

  def read_svg(path)
    # Cache by mtime so production doesn't re-read every request
    cache_key = "icon-svg:#{path}:#{path.mtime.to_i}"

    Rails.cache.fetch(cache_key) do
      s = File.read(path)
      s = s.sub(/\A<\?xml[^>]*>\s*/m, "")
      s = s.sub(/\A<!DOCTYPE[^>]*>\s*/m, "")
      s.strip
    end
  end

  def normalize_svg_attrs(attrs, class_value:, label:, title:)
    attrs = attrs.dup

    # Always apply class to the svg
    attrs[:class] = class_value

    # Default role
    attrs[:role] ||= "img"

    # Accessibility
    if label.present?
      attrs[:aria] ||= {}
      attrs[:aria][:label] ||= label
      attrs.delete(:'aria-hidden')
    else
      attrs[:'aria-hidden'] ||= "true"
      attrs[:focusable] ||= "false"
    end

    # Optional <title> element inserted inside the SVG
    attrs[:__title] = title if title.present?

    attrs
  end

  def inject_svg_opening_tag(svg, attrs)
    title_text = attrs.delete(:__title)
    flat = flatten_html_attrs(attrs)

    svg.sub(/\A\s*<svg\b([^>]*)>/m) do
      existing = Regexp.last_match(1)

      # merge/append class=""
      if flat.key?("class")
        klass = flat.delete("class").to_s
        if existing.match?(/\bclass="/)
          existing = existing.sub(/\bclass="([^"]*)"/) do
            %(class="#{$1} #{ERB::Util.html_escape(klass)}")
          end
        else
          existing += %( class="#{ERB::Util.html_escape(klass)}")
        end
      end

      extra_attrs = flat.map do |k, v|
        next if v.nil?
        %(#{k}="#{ERB::Util.html_escape(v)}")
      end.compact.join(" ")

      opening = "<svg#{existing}"
      opening += " #{extra_attrs}" if extra_attrs.present?
      opening += ">"

      if title_text.present?
        opening + "\n<title>#{ERB::Util.html_escape(title_text)}</title>"
      else
        opening
      end
    end
  end

  def flatten_html_attrs(attrs)
    out = {}

    attrs.each do |k, v|
      next if v.nil?

      case k.to_sym
      when :data
        v.to_h.each { |dk, dv| out["data-#{dk.to_s.tr('_', '-')}"] = dv }
      when :aria
        v.to_h.each { |ak, av| out["aria-#{ak.to_s.tr('_', '-')}"] = av }
      else
        out[k.to_s.tr("_", "-")] = v
      end
    end

    out
  end

  def missing_icon_fallback(library, filename)
    %(<span class="inline-block text-red-400 text-xs" title="Missing icon: #{ERB::Util.html_escape(library)}/#{ERB::Util.html_escape(filename)}">?</span>)
  end
end
