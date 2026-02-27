import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  reset(event) {
    // Only clear if the server responded successfully
    if (event.detail.success) {
      const input = this.element.querySelector("#ai_chat_input")
      if (input) {
        input.value = ""
        input.dispatchEvent(new Event("input", { bubbles: true })) // helps if anything listens to input
      }
    }
  }
}