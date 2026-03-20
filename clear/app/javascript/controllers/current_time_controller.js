import { Controller } from "@hotwired/stimulus"

// Renders a "current time" indicator line on today's column and
// dims calendar events whose start time has already passed.
export default class extends Controller {
  static targets = ["line", "label", "dayColumn"]
  static values  = { hourHeight: { type: Number, default: 72 } }

  connect() {
    this._tick()
    this._scrollToNow()
    this._timer = setInterval(() => this._tick(), 60_000) // update every minute
  }

  disconnect() {
    if (this._timer) clearInterval(this._timer)
  }

  _scrollToNow() {
    if (!this.hasLineTarget) return
    // Scroll so the current-time line sits about 1/3 from the top of the visible area
    const offset = this.hasLineTarget ? parseFloat(this.lineTarget.style.top) : 0
    const viewHeight = this.element.clientHeight
    const scrollTo = Math.max(0, offset - viewHeight / 3)
    this.element.scrollTo({ top: scrollTo, behavior: "instant" })
  }

  _tick() {
    const now = new Date()
    const minutesSinceMidnight = now.getHours() * 60 + now.getMinutes()
    const pxPerMinute = this.hourHeightValue / 60
    const topPx = minutesSinceMidnight * pxPerMinute

    // Position the red line
    if (this.hasLineTarget) {
      this.lineTarget.style.top = `${topPx}px`
    }

    // Update time label
    if (this.hasLabelTarget) {
      const h = now.getHours()
      const m = now.getMinutes()
      const ampm = h >= 12 ? "PM" : "AM"
      const h12 = h % 12 || 12
      const mm = m.toString().padStart(2, "0")
      this.labelTarget.textContent = `${h12}:${mm} ${ampm}`
    }

    // Dim events whose start time has passed
    const nowEpoch = now.getTime()
    this.element.querySelectorAll("[data-event-starts-at]").forEach((el) => {
      const startsAt = parseInt(el.dataset.eventStartsAt, 10)
      if (startsAt <= nowEpoch) {
        el.classList.add("is-past")
      } else {
        el.classList.remove("is-past")
      }
    })
  }
}
