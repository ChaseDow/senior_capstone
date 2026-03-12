import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popover", "frame", "skeleton"]

  connect() {
    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close()
    }
    this._onClickOutside = (e) => {
      if (!this._open) return
      if (this.popoverTarget.contains(e.target)) return
      if (e.target.closest("[data-calendar-event]")) return
      this.close()
    }
    window.addEventListener("keydown", this._onKeydown)
    // Use setTimeout so the current click doesn't immediately close
    document.addEventListener("click", this._onClickOutside, true)
  }

  disconnect() {
    window.removeEventListener("keydown", this._onKeydown)
    document.removeEventListener("click", this._onClickOutside, true)
  }

  show(event) {
    const anchor = event.currentTarget
    this._open = true

    // Show skeleton immediately while frame loads
    if (this.hasSkeletonTarget && this.hasFrameTarget) {
      this.frameTarget.innerHTML = this.skeletonTarget.innerHTML
    }

    this.popoverTarget.classList.remove("hidden")
    this._position(anchor)
  }

  frameLoaded() {
    // Re-position after content loads in case size changed
    if (this._lastAnchor) this._position(this._lastAnchor)
  }

  close() {
    this._open = false
    this.popoverTarget.classList.add("hidden")
    if (this.hasFrameTarget) {
      this.frameTarget.innerHTML = ""
      this.frameTarget.removeAttribute("src")
    }
  }

  _position(anchor) {
    this._lastAnchor = anchor
    const popover = this.popoverTarget
    const scrollParent = anchor.closest(".overflow-auto") || this.element

    // Briefly show off-screen to measure height
    popover.style.visibility = "hidden"
    popover.classList.remove("hidden")
    const popoverHeight = popover.offsetHeight
    const popoverWidth = 320
    popover.style.visibility = ""

    const anchorRect = anchor.getBoundingClientRect()
    const scrollRect = scrollParent.getBoundingClientRect()

    // Position above the event, like Google Calendar
    let top = anchorRect.top - scrollRect.top + scrollParent.scrollTop - popoverHeight - 8

    // If it would go above the visible scroll area, place below the event instead
    const scrollTop = scrollParent.scrollTop
    if (top < scrollTop) {
      top = anchorRect.bottom - scrollRect.top + scrollParent.scrollTop + 8
    }

    // Horizontally center on the event, clamped to bounds
    let left = anchorRect.left - scrollRect.left + (anchorRect.width / 2) - (popoverWidth / 2)
    if (left + popoverWidth > scrollParent.clientWidth - 8) {
      left = scrollParent.clientWidth - popoverWidth - 8
    }
    left = Math.max(8, left)

    popover.style.top = `${top}px`
    popover.style.left = `${left}px`
  }
}
