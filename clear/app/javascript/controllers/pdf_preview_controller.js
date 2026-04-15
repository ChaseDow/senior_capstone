import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "viewer"]

  select() {
    const file = this.inputTarget.files[0]
    if (!file || file.type !== "application/pdf") {
      this.viewerTarget.classList.add("hidden")
      return
    }

    const url = URL.createObjectURL(file)
    this.viewerTarget.src = url
    this.viewerTarget.classList.remove("hidden")
  }

  disconnect() {
    const src = this.viewerTarget.src
    if (src && src.startsWith("blob:")) {
      URL.revokeObjectURL(src)
    }
  }
}
