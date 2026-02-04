import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar"]

  connect() {
    const collapsed = localStorage.getItem("sidebar:collapsed") === "1"
    this.sidebarTarget.dataset.collapsed = collapsed ? "true" : "false"
  }

  toggle() {
    const isCollapsed = this.sidebarTarget.dataset.collapsed === "true"
    const next = (!isCollapsed).toString()
    this.sidebarTarget.dataset.collapsed = next
    localStorage.setItem("sidebar:collapsed", next === "true" ? "1" : "0")
  }
}
