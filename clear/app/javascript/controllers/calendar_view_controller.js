import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { view: { type: String, default: "weekly" } }
  static targets = ["weeklyView", "monthlyView", "weeklyNav", "monthlyNav", "weeklyTitle", "monthlyTitle", "selector"]

  connect() {
    const saved = localStorage.getItem("calendar:view")
    if (saved === "monthly" || saved === "weekly") {
      this.viewValue = saved
    }
    this.syncView()
  }

  viewValueChanged() {
    this.syncView()
  }

  toggle(event) {
    this.viewValue = event.target.value
    localStorage.setItem("calendar:view", this.viewValue)
  }

  syncView() {
    const isMonthly = this.viewValue === "monthly"

    this.#toggle(this.weeklyViewTargets, !isMonthly)
    this.#toggle(this.monthlyViewTargets, isMonthly)
    this.#toggle(this.weeklyNavTargets, !isMonthly)
    this.#toggle(this.monthlyNavTargets, isMonthly)
    this.#toggle(this.weeklyTitleTargets, !isMonthly)
    this.#toggle(this.monthlyTitleTargets, isMonthly)

    if (this.hasSelectorTarget) {
      this.selectorTarget.value = this.viewValue
    }
  }

  #toggle(targets, show) {
    targets.forEach(el => {
      if (show) {
        el.style.removeProperty("display")
      } else {
        el.style.display = "none"
      }
    })
  }
}
