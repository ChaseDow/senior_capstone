// app/javascript/controllers/poll_frame_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    active: Boolean,
    interval: Number,
    src: String,
  }

  connect() {
    this.start()
  }

  disconnect() {
    this.stop()
  }

  activeValueChanged() {
    this.start()
  }

  start() {
    this.stop()
    if (!this.activeValue) return

    const ms = this.intervalValue || 1500
    this.timer = setInterval(() => this.reload(), ms)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
  }

  reload() {
    const base = this.srcValue
    if (!base) return

    const url = new URL(base, window.location.origin)
    url.searchParams.set("_ts", Date.now()) // bust cache
    this.element.setAttribute("src", url.toString())
  }
}
