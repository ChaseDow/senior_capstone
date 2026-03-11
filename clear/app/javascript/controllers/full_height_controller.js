import { Controller } from "@hotwired/stimulus"

// Expands the main content wrapper to fill the full height of the viewport,
// removing its padding so the child view can control its own layout.
// Restores the original styles on disconnect (page navigation).
export default class extends Controller {
  connect() {
    const main = this.element.closest("main")
    if (!main) return
    const wrapper = main.querySelector(":scope > div")
    if (!wrapper) return

    this._main = main
    this._wrapper = wrapper
    this._prev = {
      mainOverflow: main.style.overflow,
      wrapperHeight: wrapper.style.height,
      wrapperPadding: wrapper.style.padding,
      wrapperOverflow: wrapper.style.overflow,
    }

    main.style.overflow = "hidden"
    wrapper.style.height = "100%"
    wrapper.style.padding = "0"
    wrapper.style.overflow = "hidden"
  }

  disconnect() {
    if (!this._prev) return
    if (this._main) this._main.style.overflow = this._prev.mainOverflow
    if (this._wrapper) {
      this._wrapper.style.height = this._prev.wrapperHeight
      this._wrapper.style.padding = this._prev.wrapperPadding
      this._wrapper.style.overflow = this._prev.wrapperOverflow
    }
  }
}
