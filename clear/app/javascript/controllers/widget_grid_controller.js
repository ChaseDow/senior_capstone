import { Controller } from "@hotwired/stimulus"
import { GridStack } from "gridstack"

// Initializes a Gridstack grid over the element, persists layout changes
// to the server, and watches for items added/removed via Turbo Streams so
// the grid stays in sync with the DOM.
export default class extends Controller {
  static values = { reorderUrl: String }

  connect() {
    this.grid = GridStack.init(
      {
        column: 12,
        cellHeight: 80,
        margin: 10,
        float: false,
        animate: true,
        handle: ".grid-stack-handle",
        resizable: { handles: "se, sw, e, s, w" },
        minRow: 1
      },
      this.element
    )

    this.grid.on("change", () => this.scheduleSave())

    this._observer = new MutationObserver((mutations) => this.handleMutations(mutations))
    this._observer.observe(this.element, { childList: true })
  }

  disconnect() {
    this._observer?.disconnect()
    if (this._saveTimer) window.clearTimeout(this._saveTimer)
    this.grid?.destroy(false)
    this.grid = null
  }

  handleMutations(mutations) {
    if (!this.grid) return

    for (const m of mutations) {
      m.addedNodes.forEach((node) => {
        if (!(node instanceof HTMLElement)) return
        if (!node.classList.contains("grid-stack-item")) return
        if (node.gridstackNode) return

        try {
          this.grid.makeWidget(node)
        } catch (e) {
          console.error("Failed to register widget with Gridstack", e)
        }
      })

      m.removedNodes.forEach((node) => {
        if (!(node instanceof HTMLElement)) return
        if (!node.classList.contains("grid-stack-item")) return
        if (!node.gridstackNode) return

        try {
          this.grid.removeWidget(node, false)
        } catch (e) {
          // The node is already detached — gridstack just needs to forget it.
        }
      })
    }
  }

  scheduleSave() {
    if (this._saveTimer) window.clearTimeout(this._saveTimer)
    this._saveTimer = window.setTimeout(() => this.saveLayout(), 250)
  }

  saveLayout() {
    if (!this.grid) return

    const positions = this.grid.save(false).map((item) => ({
      id: item.id,
      x: item.x,
      y: item.y,
      w: item.w,
      h: item.h
    }))

    if (positions.length === 0) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.reorderUrlValue, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken || ""
      },
      body: JSON.stringify({ positions })
    }).catch((err) => console.error("Failed to save widget layout", err))
  }
}
