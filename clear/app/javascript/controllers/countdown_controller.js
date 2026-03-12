import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { eventTime: String }

  connect() {
    this.display = this.element.querySelector("[data-countdown-display]")
    if (!this.display) return
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  tick() {
    const target = new Date(this.eventTimeValue)
    const now = new Date()
    const diff = Math.floor((target - now) / 1000)

    if (diff <= 0) {
      this.display.textContent = "starting now"
      clearInterval(this.interval)
      return
    }

    const days = Math.floor(diff / 86400)
    const hours = Math.floor((diff % 86400) / 3600)
    const minutes = Math.floor((diff % 3600) / 60)
    const seconds = diff % 60

    let text
    if (days > 0) {
      text = `in ${days}d ${hours}h`
    } else if (hours > 0) {
      text = `in ${hours}h ${minutes}m`
    } else if (minutes > 0) {
      text = `in ${minutes}m ${seconds}s`
    } else {
      text = `in ${seconds}s`
    }

    this.display.textContent = text
  }
}
