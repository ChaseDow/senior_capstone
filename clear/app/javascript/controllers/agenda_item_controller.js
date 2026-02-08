import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String }

  select(event) {
    if (event.target.closest("a, button")) return

    document.querySelectorAll("[data-agenda-item-card].is-selected").forEach((el) => {
      el.classList.remove("is-selected")
    })

    this.element.classList.add("is-selected")

    if (this.idValue) {
      window.dispatchEvent(new CustomEvent("agenda:select", { detail: { id: this.idValue } }))
    }
  }
}


