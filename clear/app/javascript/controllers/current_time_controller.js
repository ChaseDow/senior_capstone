import { Controller } from "@hotwired/stimulus"

// Renders a "current time" indicator line on today's column and
// dulls calendar events whose end time has already passed.
export default class extends Controller {
  static targets = ["line", "dayColumn"]
  static values  = { hourHeight: { type: Number, default: 72 } }

  connect() {
    this._tick()
    this._timer = setInterval(() => this._tick(), 60_000) // update every minute
  }

  disconnect() {
    if (this._timer) clearInterval(this._timer)
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

    // Mark past events
    const nowEpoch = now.getTime()
    this.element.querySelectorAll("[data-event-ends-at]").forEach((el) => {
      const endsAt = parseInt(el.dataset.eventEndsAt, 10)
      if (endsAt <= nowEpoch) {
        el.classList.add("is-past")
      } else {
        el.classList.remove("is-past")
      }
    })
  }
}
