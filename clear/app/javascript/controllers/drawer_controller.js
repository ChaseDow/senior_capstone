import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel", "frame", "skeleton"]
  static values = { open: Boolean }

  connect() {
    this.openValue = false

    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close()
    }
    window.addEventListener("keydown", this._onKeydown)

    this.render()
  }

  disconnect() {
    window.removeEventListener("keydown", this._onKeydown)
  }

  open() {
    this.openValue = true
    this.render()
  }

  close(event) {
    event?.preventDefault()
    this.openValue = false
    this.render()

    window.setTimeout(() => {
      if (!this.openValue && this.hasFrameTarget) this.frameTarget.innerHTML = ""
    }, 320)
  }

  frameLoaded() {
    this.open()
  }

  showSkeleton() {
    if (!this.hasSkeletonTarget || !this.hasFrameTarget) return
    this.frameTarget.innerHTML = this.skeletonTarget.innerHTML
  }

  submitEnded(event) {
    if (!event.detail?.success) {
      this.open()
      return
    }

    const form = event.detail.formSubmission?.formElement
    const shouldClose = form?.dataset?.drawerCloseOnSuccess === "true"
    if (shouldClose) this.close()
  }

  render() {
    if (!this.hasOverlayTarget || !this.hasPanelTarget) return

    if (this.openValue) {
      this.overlayTarget.classList.remove("opacity-0", "pointer-events-none")
      this.overlayTarget.classList.add("opacity-100")

      this.panelTarget.classList.remove("translate-x-[110vw]")
      this.panelTarget.classList.add("translate-x-0")
    } else {
      this.overlayTarget.classList.add("opacity-0", "pointer-events-none")
      this.overlayTarget.classList.remove("opacity-100")

      this.panelTarget.classList.add("translate-x-[110vw]")
      this.panelTarget.classList.remove("translate-x-0")
    }
  }
}
