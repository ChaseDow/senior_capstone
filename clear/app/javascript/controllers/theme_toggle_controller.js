import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("hit")
    const saved = localStorage.getItem("mode")
    const mode = saved || "black"
    this.apply(mode)
  }

  set(event) {
    const mode = event.currentTarget.dataset.mode
    this.apply(mode)
  }

  apply(mode) {
    document.body.dataset.mode = mode
    localStorage.setItem("mode", mode)
  }
}
