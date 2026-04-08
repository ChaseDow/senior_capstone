import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["weeklyWrapper", "monthlyWrapper", "selector", "weeklyContent", "monthlyContent"]

  connect() {
    const saved = localStorage.getItem("calendar:view")
    this.currentView = (saved === "monthly") ? "monthly" : "weekly"
    this.syncView()
  }

  toggle(event) {
    this.currentView = event.target.value
    localStorage.setItem("calendar:view", this.currentView)
    this.syncView()
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

    this.selectorTargets.forEach(sel => {
      sel.value = this.currentView
    })
  }
}
