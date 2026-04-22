import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const saved = localStorage.getItem("analytics:active-tab") || "overview"
    this.activateTab(saved)
  }

  switch(event) {
    const tab = event.currentTarget.dataset.tab
    localStorage.setItem("analytics:active-tab", tab)
    this.activateTab(tab)
  }

  activateTab(name) {
    this.tabTargets.forEach(el => {
      el.dataset.active = String(el.dataset.tab === name)
    })
    this.panelTargets.forEach(el => {
      const isActive = el.dataset.panel === name
      el.classList.toggle("hidden", !isActive)
    })
    // Notify controllers inside the newly-active panel so they can fix any
    // layout calculations that were deferred while the panel was display:none.
    window.dispatchEvent(new CustomEvent("analytics:tab-activated", { detail: { tab: name } }))
  }
}
