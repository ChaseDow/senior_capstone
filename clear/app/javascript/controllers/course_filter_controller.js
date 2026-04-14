import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { baseUrl: String, startDate: String }

  navigate(event) {
    const filterValue = event.detail?.value ?? ""
    const url         = new URL(this.baseUrlValue, window.location.origin)
    url.searchParams.set("start_date", this.startDateValue)
    if (filterValue) {
      url.searchParams.set("filter", filterValue)
    } else {
      url.searchParams.delete("filter")
    }

    // Navigate the frame directly (same mechanism as Prev/Next/Today links) so
    // Stimulus controllers outside the frame are untouched — no full-body teardown
    // and no flash of the default weekly state before localStorage can restore the
    // view. data-turbo-action="advance" pushes the URL to browser history so the
    // filter persists on reload and is shareable/bookmarkable.
    const a = document.createElement("a")
    a.href = url.toString()
    a.dataset.turboFrame  = "dashboard_calendar"
    a.dataset.turboAction = "advance"
    document.body.appendChild(a)
    a.click()
    a.remove()
  }
}
