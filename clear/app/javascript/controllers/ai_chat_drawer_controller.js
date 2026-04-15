import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel", "frame"]
  static values = { url: String }

  connect() {
    this._open = false
    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close()
    }
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
  }

  toggle() {
    if (this._open) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this._open = true

    this.overlayTarget.classList.remove("opacity-0", "pointer-events-none")
    this.overlayTarget.classList.add("opacity-100")

    this.panelTarget.classList.remove("translate-x-full")
    this.panelTarget.classList.add("translate-x-0")
    this.panelTarget.style.visibility = "visible"

    // Load content only once — preserves chat history across opens
    if (this.hasFrameTarget && !this.frameTarget.src) {
      this.frameTarget.src = this.urlValue
    }
  }

  close() {
    this._open = false

    this.overlayTarget.classList.add("opacity-0", "pointer-events-none")
    this.overlayTarget.classList.remove("opacity-100")

    this.panelTarget.classList.add("translate-x-full")
    this.panelTarget.classList.remove("translate-x-0")

    window.setTimeout(() => {
      this.panelTarget.style.visibility = "hidden"
    }, 300)

    // Refresh the page if the dashboard calendar is present so AI-created events appear
    const calendarFrame = document.getElementById("dashboard_calendar")
    if (calendarFrame) {
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }
}
