import { Controller } from "@hotwired/stimulus"

// Handles clicks on widget-picker cards. Explicitly fetches the configure URL
// and swaps the response into the widget_modal turbo-frame, bypassing any
// quirks with Turbo Frame link delegation when the link lives inside the frame
// it targets.
export default class extends Controller {
  select(event) {
    event.preventDefault()
    event.stopPropagation()

    const url = event.currentTarget.dataset.widgetPickerUrlValue ||
                event.currentTarget.getAttribute("href")
    if (!url) return

    const frame = document.getElementById("widget_modal")
    if (!frame) {
      console.error("widget-picker: widget_modal frame not found")
      return
    }

    fetch(url, {
      headers: {
        "Accept": "text/html, application/xhtml+xml",
        "Turbo-Frame": "widget_modal"
      },
      credentials: "same-origin"
    })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        return res.text()
      })
      .then((html) => {
        const doc = new DOMParser().parseFromString(html, "text/html")
        const next = doc.querySelector("turbo-frame#widget_modal")
        if (next) {
          frame.innerHTML = next.innerHTML
        } else {
          frame.innerHTML = html
        }
      })
      .catch((err) => console.error("widget-picker: fetch failed", err))
  }
}
