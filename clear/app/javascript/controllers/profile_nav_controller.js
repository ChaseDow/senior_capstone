import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["navLink", "section", "scroll"]

  connect() {
    this._observer = new IntersectionObserver(
      (entries) => {
        let bestEntry = null

        entries.forEach((entry) => {
          if (!entry.isIntersecting) return
          if (!bestEntry || entry.intersectionRatio > bestEntry.intersectionRatio) {
            bestEntry = entry
          }
        })

        if (!bestEntry) return
        this.setActive(bestEntry.target.id)
      },
      {
        root: this.scrollTarget,
        rootMargin: "-12% 0px -55% 0px",
        threshold: [0.25, 0.5, 0.75]
      }
    )

    this.sectionTargets.forEach((section) => this._observer.observe(section))
    this.setActive(this.sectionTargets[0]?.id)
  }

  disconnect() {
    if (this._observer) this._observer.disconnect()
  }

  focus(event) {
    event.preventDefault()

    const id = event.currentTarget.dataset.profileNavId
    const section = this.sectionTargets.find((target) => target.id === id)
    if (!section) return

    section.scrollIntoView({ behavior: "smooth", block: "start", inline: "nearest" })
    this.setActive(id)
  }

  setActive(id) {
    this.navLinkTargets.forEach((link) => {
      const isSelected = link.dataset.profileNavId === id
      link.classList.toggle("is-selected", isSelected)
      link.setAttribute("aria-current", isSelected ? "true" : "false")
    })
  }
}
