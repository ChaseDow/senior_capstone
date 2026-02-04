module ApplicationHelper
  def rgba(hex, alpha)
    h = hex.to_s.delete("#")
    return "rgba(52,211,153,#{alpha})" unless h.match?(/\A\h{6}\z/)

    r, g, b = h.scan(/../).map(&:hex)
    "rgba(#{r},#{g},#{b},#{alpha})"
  end
end
