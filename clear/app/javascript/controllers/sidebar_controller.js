import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  connect() {
    const collapsed = localStorage.getItem("sidebar:collapsed") === "1"
    this.sidebarTarget.dataset.collapsed = collapsed ? "true" : "false"
  }

  get isMobile() {
    return !window.matchMedia("(min-width: 768px)").matches
  }

  toggle() {
    if (this.isMobile) {
      this.closeMobile()
      return
    }
    const isCollapsed = this.sidebarTarget.dataset.collapsed === "true"
    const next = (!isCollapsed).toString()
    this.sidebarTarget.dataset.collapsed = next
    localStorage.setItem("sidebar:collapsed", next === "true" ? "1" : "0")
  }

  openMobile() {
    this.sidebarTarget.dataset.mobileOpen = "true"
    if (this.hasOverlayTarget) this.overlayTarget.classList.remove("hidden")
  }

  closeMobile() {
    this.sidebarTarget.dataset.mobileOpen = "false"
    if (this.hasOverlayTarget) this.overlayTarget.classList.add("hidden")
  }
}
