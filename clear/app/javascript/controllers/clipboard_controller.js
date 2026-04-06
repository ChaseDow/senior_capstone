// app/javascript/controllers/clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue)
      .then(() => {
        alert("Invite link copied!") // you can replace with toast UI
      })
      .catch(() => {
        alert("Failed to copy link")
      })
  }
}
