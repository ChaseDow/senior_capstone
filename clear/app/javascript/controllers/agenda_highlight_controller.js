import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.selectedId = null

    this._onSelect = (e) => this.highlight(e.detail?.id)
    this._onClear  = () => this.clear()

    window.addEventListener("agenda:select", this._onSelect)
    window.addEventListener("agenda:clear", this._onClear)
  }

  disconnect() {
    window.removeEventListener("agenda:select", this._onSelect)
    window.removeEventListener("agenda:clear", this._onClear)
  }

  selectFromAgenda(event) {
    if (event.target.closest("a, button")) return

    const id = event.currentTarget.dataset.agendaId
    if (!id) return

    if (this.selectedId === id) {
      window.dispatchEvent(new CustomEvent("agenda:clear"))
    } else {
      window.dispatchEvent(new CustomEvent("agenda:select", { detail: { id } }))
    }
  }

  selectFromCalendar(event) {
    const id = event.currentTarget.id
    if (!id) return

    if (this.selectedId === id) {
      window.dispatchEvent(new CustomEvent("agenda:clear"))
    } else {
      window.dispatchEvent(new CustomEvent("agenda:select", { detail: { id } }))
    }
  }

  highlight(id) {
    if (!id) return

    this.selectedId = id

    document
      .querySelectorAll("[data-calendar-event].is-selected")
      .forEach((el) => el.classList.remove("is-selected"))

    const cal = document.getElementById(id)
    if (cal) {
      cal.classList.add("is-selected")
      cal.scrollIntoView({ block: "center", behavior: "smooth" })
    }

    this._selectAgendaCard(id)
  }

  clear() {
    this.selectedId = null

    document
      .querySelectorAll(".is-selected")
      .forEach((el) => el.classList.remove("is-selected"))
  }

  _selectAgendaCard(id) {
    document
      .querySelectorAll("[data-agenda-item-card].is-selected")
      .forEach((el) => el.classList.remove("is-selected"))

    const card = document.getElementById(`agenda-item-${id}`)
    if (card) card.classList.add("is-selected")
  }
}
