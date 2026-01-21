import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel", "frame"]
  static values = { open: Boolean }

  connect() {
    this.openValue = false

    this.closedPanelClass = "translate-x-[110vw]"
    this.openPanelClass = "translate-x-0"

    if (this.hasFrameTarget) this.skeletonHtml = this.frameTarget.innerHTML

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

  openAndLoad(event) {
    event?.preventDefault()

    const url = event?.currentTarget?.dataset?.drawerUrl
    if (!this.hasFrameTarget || !url) {
      this.open()
      return
    }

    if (this.skeletonHtml != null) this.frameTarget.innerHTML = this.skeletonHtml

    this.open()
    this.frameTarget.setAttribute("src", url)
  }

  close(event) {
    event?.preventDefault()

    this.openValue = false
    this.render()

    window.setTimeout(() => {
      if (this.openValue || !this.hasFrameTarget) return

      this.frameTarget.removeAttribute("src")
      if (this.skeletonHtml != null) this.frameTarget.innerHTML = this.skeletonHtml
    }, 320)
  }

  frameLoaded() {
    this.open()
  }

  submitEnded(event) {
    if (event.detail?.success) this.close()
  }

  render() {
    if (!this.hasOverlayTarget || !this.hasPanelTarget) return

    if (this.openValue) {
      this.overlayTarget.classList.remove("opacity-0", "pointer-events-none")
      this.overlayTarget.classList.add("opacity-100")

      this.panelTarget.classList.remove(this.closedPanelClass)
      this.panelTarget.classList.add(this.openPanelClass)
    } else {
      this.overlayTarget.classList.add("opacity-0", "pointer-events-none")
      this.overlayTarget.classList.remove("opacity-100")

      this.panelTarget.classList.add(this.closedPanelClass)
      this.panelTarget.classList.remove(this.openPanelClass)
    }
  }
}
