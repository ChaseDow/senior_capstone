import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "checkboxWrapper", "selectButton", "actionBar", "countLabel"]
  static values = { url: String }

  connect() {
    this.selecting = false
    this.lastCheckedIndex = -1
  }

  toggleMode() {
    this.selecting = !this.selecting
    if (this.selecting) {
      this.selectButtonTarget.textContent = "Cancel"
      this.selectButtonTarget.style.borderColor = "rgba(239,68,68,0.4)"
      this.selectButtonTarget.style.color = "#fca5a5"
      this.checkboxWrapperTargets.forEach(w => { w.style.display = "flex" })
    } else {
      this.selectButtonTarget.textContent = "Select"
      this.selectButtonTarget.style.borderColor = ""
      this.selectButtonTarget.style.color = ""
      this.checkboxWrapperTargets.forEach(w => { w.style.display = "none" })
      this.checkboxTargets.forEach(cb => { cb.checked = false })
      this.actionBarTarget.style.display = "none"
      this.lastCheckedIndex = -1
    }
  }

  toggle(event) {
    const checkbox = event.target
    const checkboxes = this.checkboxTargets
    const currentIndex = checkboxes.indexOf(checkbox)

    if (event.shiftKey && this.lastCheckedIndex >= 0 && currentIndex !== this.lastCheckedIndex) {
      const start = Math.min(this.lastCheckedIndex, currentIndex)
      const end = Math.max(this.lastCheckedIndex, currentIndex)
      const checked = checkbox.checked
      for (let i = start; i <= end; i++) {
        checkboxes[i].checked = checked
      }
    }

    this.lastCheckedIndex = currentIndex
    this.updateActionBar()
  }

  updateActionBar() {
    const count = this.checkboxTargets.filter(cb => cb.checked).length
    if (count > 0) {
      this.countLabelTarget.textContent = `${count} selected`
      this.actionBarTarget.style.display = "flex"
    } else {
      this.actionBarTarget.style.display = "none"
    }
  }

  deleteSelected() {
    const checked = this.checkboxTargets.filter(cb => cb.checked)
    const count = checked.length
    if (count === 0) return
    if (!confirm(`Delete ${count} item${count !== 1 ? "s" : ""}? This cannot be undone.`)) return

    const ids = checked.map(cb => cb.value)
    const form = document.createElement("form")
    form.method = "post"
    form.action = this.urlValue
    form.style.display = "none"

    const addInput = (name, value) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      form.appendChild(input)
    }

    addInput("_method", "delete")
    const tokenMeta = document.querySelector("meta[name='csrf-token']")
    if (tokenMeta) addInput("authenticity_token", tokenMeta.content)
    ids.forEach(id => addInput("ids[]", id))

    document.body.appendChild(form)
    form.submit()
  }
}
