import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.boundClose = this.closeOnOutsideClick.bind(this)
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.panelTarget.classList.remove("hidden")
    this.isOpen = true
    document.addEventListener("click", this.boundClose)

    // Always reload the frame so badge + panel reflect the latest state
    const frame = this.panelTarget.querySelector("turbo-frame")
    if (frame && frame.src) {
      frame.reload()
    }
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.isOpen = false
    document.removeEventListener("click", this.boundClose)
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }
}
