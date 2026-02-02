import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    status: String,
    interval: { type: Number, default: 1500 },
  }

  connect() {
    this.startIfNeeded()
  }

  disconnect() {
    this.stop()
  }

  startIfNeeded() {
    if (this.statusValue === "queued" || this.statusValue === "processing") {
      this.start()
    } else {
      this.stop()
    }
  }

  start() {
    if (this.timer) return
    this.timer = setInterval(() => {
      const frame = this.element.closest("turbo-frame")
      if (frame) frame.reload()
    }, this.intervalValue)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
  }
}
