import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["flag", "card", "removeBtn", "undoBtn"]

  remove() {
    this.flagTarget.value = "1"
    this.cardTarget.style.opacity = "0.3"
    this.cardTarget.style.pointerEvents = "none"
    this.removeBtnTarget.style.display = "none"
    this.undoBtnTarget.style.display = "inline-flex"
  }

  undo() {
    this.flagTarget.value = "0"
    this.cardTarget.style.opacity = "1"
    this.cardTarget.style.pointerEvents = "auto"
    this.removeBtnTarget.style.display = "inline-flex"
    this.undoBtnTarget.style.display = "none"
  }
}
