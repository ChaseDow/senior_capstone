import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  clear() {
    window.Turbo?.cache?.clear?.()
  }

  clearSearch() {
    this.clear()

    document.querySelectorAll('form[data-controller~="search"] input[name="q"]').forEach((input) => {
      input.value = ""
    })
  }
}
