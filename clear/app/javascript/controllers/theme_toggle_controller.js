import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  set(event) {
    const mode = event.currentTarget.dataset.mode
    if (!mode) return

    document.documentElement.dataset.mode = mode
    localStorage.setItem("mode", mode)
  }
}
