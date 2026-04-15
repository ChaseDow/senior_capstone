import { Controller } from "@hotwired/stimulus"

const DASHBOARD_VIEW_TOGGLE_NAME = "calendar_dashboard"

export default class extends Controller {
  static targets = ["weeklyWrapper", "monthlyWrapper"]

  connect() {
    const saved = localStorage.getItem("calendar:view")
    this.currentView = (saved === "monthly") ? "monthly" : "weekly"
    this.syncView()
  }

  toggle(event) {
    const nextView = event?.detail?.value || event?.target?.value
    if (!["weekly", "monthly"].includes(nextView)) return

    this.currentView = nextView
    localStorage.setItem("calendar:view", this.currentView)
    this.syncView()
    if (event?.detail) this.focusActiveViewToggle()
  }

  syncView() {
    const isMonthly = this.currentView === "monthly"

    if (this.hasWeeklyWrapperTarget) {
      this.weeklyWrapperTarget.classList.toggle("hidden", isMonthly)
      this.weeklyWrapperTarget.style.display = isMonthly ? "none" : ""
    }
    if (this.hasMonthlyWrapperTarget) {
      this.monthlyWrapperTarget.style.display = isMonthly ? "flex" : "none"
      this.monthlyWrapperTarget.classList.toggle("hidden", !isMonthly)
    }

    this.syncToggleDropdowns()
  }

  syncToggleDropdowns() {
    this.element.querySelectorAll('[data-controller~="dropdown"]').forEach((dropdown) => {
      const input = dropdown.querySelector(`input.dropdown-input[name="${DASHBOARD_VIEW_TOGGLE_NAME}"]`)
      if (!input) return

      input.value = this.currentView

      const items = dropdown.querySelectorAll(".dropdown-item")
      items.forEach((item) => {
        item.dataset.selected = "false"
      })

      const selected = dropdown.querySelector(`.dropdown-item[data-dropdown-value-param="${this.currentView}"]`)
      if (!selected) return

      selected.dataset.selected = "true"

      const label = dropdown.querySelector(".dropdown-label")
      if (!label) return

      label.textContent = selected.dataset.dropdownLabelParam || selected.textContent.trim()
    })
  }

  focusActiveViewToggle() {
    const activeWrapper = this.currentView === "monthly"
      ? (this.hasMonthlyWrapperTarget ? this.monthlyWrapperTarget : null)
      : (this.hasWeeklyWrapperTarget ? this.weeklyWrapperTarget : null)
    if (!activeWrapper) return

    const activeInput = activeWrapper.querySelector(`input.dropdown-input[name="${DASHBOARD_VIEW_TOGGLE_NAME}"]`)
    const toggleButton = activeInput?.closest('[data-controller~="dropdown"]')?.querySelector(".dropdown-toggle")
    if (!toggleButton) return

    requestAnimationFrame(() => {
      toggleButton.focus({ preventScroll: true })
    })
  }
}
