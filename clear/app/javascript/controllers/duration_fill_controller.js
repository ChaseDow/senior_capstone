import { Controller } from "@hotwired/stimulus"

// Watches a duration select and auto-fills an end-time field based on start + duration.
// Works with both datetime-local ("2026-03-25T14:00") and time ("14:00") input types.
export default class extends Controller {
  static targets = ["startField", "endField", "durationField"]

  fill() {
    const minutes = parseInt(this.durationFieldTarget.value, 10)
    const startValue = this.startFieldTarget.value

    if (!minutes || !startValue) return

    if (startValue.includes("T")) {
      // datetime-local field
      const start = new Date(startValue)
      if (isNaN(start)) return
      const end = new Date(start.getTime() + minutes * 60000)
      const p = n => String(n).padStart(2, "0")
      this.endFieldTarget.value =
        `${end.getFullYear()}-${p(end.getMonth() + 1)}-${p(end.getDate())}T${p(end.getHours())}:${p(end.getMinutes())}`
    } else {
      // time field ("HH:MM")
      const [h, m] = startValue.split(":").map(Number)
      if (isNaN(h) || isNaN(m)) return
      const total = h * 60 + m + minutes
      const p = n => String(n).padStart(2, "0")
      this.endFieldTarget.value = `${p(Math.floor(total / 60) % 24)}:${p(total % 60)}`
    }
  }

  // When the end-time field changes, update the duration select to match.
  reverseFill() {
    const startValue = this.startFieldTarget.value
    const endValue = this.endFieldTarget.value

    if (!startValue || !endValue) return

    let diffMinutes

    if (startValue.includes("T")) {
      const start = new Date(startValue)
      const end = new Date(endValue)
      if (isNaN(start) || isNaN(end)) return
      diffMinutes = Math.round((end - start) / 60000)
    } else {
      const [sh, sm] = startValue.split(":").map(Number)
      const [eh, em] = endValue.split(":").map(Number)
      if (isNaN(sh) || isNaN(sm) || isNaN(eh) || isNaN(em)) return
      diffMinutes = (eh * 60 + em) - (sh * 60 + sm)
    }

    const select = this.durationFieldTarget
    // If the diff matches an option, select it; otherwise clear the select.
    const option = [...select.options].find(o => parseInt(o.value, 10) === diffMinutes)
    select.value = option ? option.value : ""
  }
}
