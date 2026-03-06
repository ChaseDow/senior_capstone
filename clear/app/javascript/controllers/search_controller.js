import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form"]

  connect() {
    this._timer = null
  }

  // Fires on every keystroke — debounced 300ms
  search() {
    clearTimeout(this._timer)
    this._timer = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 300)
  }

  // Fires on Enter key
  submit(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      clearTimeout(this._timer)
      this.formTarget.requestSubmit()
    }
  }
}