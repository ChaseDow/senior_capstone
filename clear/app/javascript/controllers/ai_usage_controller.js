import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["rpmBar", "rpmText", "rpdBar", "rpdText"]

  connect() {
    this.poll()
    this.interval = setInterval(() => this.poll(), 10000) // every 10s
  }

  disconnect() {
    if (this.interval) clearInterval(this.interval)
  }

  async poll() {
    try {
      const resp = await fetch(this.urlValue, {
        headers: { "Accept": "application/json" }
      })
      if (!resp.ok) return
      const data = await resp.json()
      this.update(data)
    } catch {
      // silently ignore fetch errors
    }
  }

  update(data) {
    const rpmPct = Math.min((data.rpm / data.rpm_limit) * 100, 100)
    const rpdPct = Math.min((data.rpd / data.rpd_limit) * 100, 100)

    if (this.hasRpmBarTarget) {
      this.rpmBarTarget.style.width = `${rpmPct}%`
      this.rpmBarTarget.style.backgroundColor = this.barColor(rpmPct)
    }
    if (this.hasRpmTextTarget) {
      this.rpmTextTarget.textContent = `${data.rpm} / ${data.rpm_limit}`
      this.rpmTextTarget.style.color = this.textColor(rpmPct)
    }
    if (this.hasRpdBarTarget) {
      this.rpdBarTarget.style.width = `${rpdPct}%`
      this.rpdBarTarget.style.backgroundColor = this.barColor(rpdPct)
    }
    if (this.hasRpdTextTarget) {
      this.rpdTextTarget.textContent = `${data.rpd} / ${data.rpd_limit}`
      this.rpdTextTarget.style.color = this.textColor(rpdPct)
    }
  }

  barColor(pct) {
    if (pct >= 90) return "#ef4444"
    if (pct >= 70) return "#f59e0b"
    return "#22c55e"
  }

  textColor(pct) {
    if (pct >= 90) return "#fca5a5"
    if (pct >= 70) return "#fcd34d"
    return "#86efac"
  }
}
