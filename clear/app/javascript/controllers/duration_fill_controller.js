import { Controller } from "@hotwired/stimulus"

// Watches a duration field and auto-fills an end-time field based on start + duration.
// Works with both datetime-local ("2026-03-25T14:00") and time ("14:00") input types.
export default class extends Controller {
  static targets = ["startField", "endField", "durationField"]

  connect() {
    this.element.querySelectorAll(".dropdown-wrapper .dropdown-label").forEach((label) => {
      if (!label.dataset.defaultLabel) {
        label.dataset.defaultLabel = label.textContent.trim()
      }
    })
  }

  fill(event) {
    const minutes = this.resolveDurationMinutes(event)
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

  // When the end-time field changes, update the duration field to match.
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

    this.assignDurationValue(diffMinutes)
  }

  resolveDurationMinutes(event) {
    if (event?.detail?.value !== undefined) {
      return parseInt(event.detail.value, 10)
    }

    if (this.hasDurationFieldTarget) {
      return parseInt(this.durationFieldTarget.value, 10)
    }

    const fallback = this.element.querySelector('input.dropdown-input[name$="[duration_minutes]"]')
    return fallback ? parseInt(fallback.value, 10) : NaN
  }

  assignDurationValue(minutes) {
    if (this.hasDurationFieldTarget) {
      const select = this.durationFieldTarget
      const option = [...select.options].find(o => parseInt(o.value, 10) === minutes)
      select.value = option ? option.value : ""
      return
    }

    const dropdownInput = this.element.querySelector('input.dropdown-input[name$="[duration_minutes]"]')
    if (!dropdownInput) return

    const dropdown = dropdownInput.closest("[data-controller~='dropdown']") || dropdownInput.closest(".dropdown-wrapper")
    if (!dropdown) {
      dropdownInput.value = Number.isFinite(minutes) ? String(minutes) : ""
      return
    }

    const option = dropdown.querySelector(`.dropdown-item[data-dropdown-value-param="${minutes}"]`)
    const label = dropdown.querySelector(".dropdown-label")

    dropdown.querySelectorAll(".dropdown-item").forEach((item) => {
      item.dataset.selected = "false"
    })

    if (option) {
      dropdownInput.value = String(minutes)
      option.dataset.selected = "true"

      if (label) {
        label.textContent = option.dataset.dropdownLabelParam || option.textContent.trim()
      }
    } else {
      dropdownInput.value = ""

      if (label) {
        label.textContent = label.dataset.defaultLabel || "— select duration —"
      }
    }
  }
}
