import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "editButton", "actions", "input"]

  edit() {
    this.showEditState()
    this.focusInputAtEnd()
  }

  cancel() {
    this.showReadState()
    this.inputTarget.value = this.displayTarget.textContent.trim()
  }

  showEditState() {
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.formTarget.classList.add("flex")

    // studs-nav-btn forces display, so hide via inline style.
    this.editButtonTarget.style.display = "none"
    this.actionsTarget.classList.remove("hidden")
    this.actionsTarget.classList.add("flex")
  }

  showReadState() {
    this.formTarget.classList.add("hidden")
    this.formTarget.classList.remove("flex")
    this.displayTarget.classList.remove("hidden")

    this.actionsTarget.classList.add("hidden")
    this.actionsTarget.classList.remove("flex")
    this.editButtonTarget.style.display = ""
  }

  focusInputAtEnd() {
    this.inputTarget.focus()
    const len = this.inputTarget.value.length
    this.inputTarget.setSelectionRange(len, len)
  }
}
