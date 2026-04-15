import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "arrow", "label", "input"]

  connect() {
    this.boundClose = this.closeOnOutsideClick.bind(this)
  }

  toggle() {
    this.isOpen() ? this.close() : this.open()
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.arrowTarget.classList.add("rotate-180")
    document.addEventListener("click", this.boundClose)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.arrowTarget.classList.remove("rotate-180")
    document.removeEventListener("click", this.boundClose)
  }

  select(event) {
    const { label, value } = event.params

    this.labelTarget.textContent = label
    this.inputTarget.value = value

    this.element.querySelectorAll(".dropdown-item").forEach((item) => {
      item.dataset.selected = "false"
    })

    event.currentTarget.dataset.selected = "true"
    this.dispatch("select", { detail: { label, value } })
    this.close()
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  isOpen() {
    return !this.menuTarget.classList.contains("hidden")
  }
}
