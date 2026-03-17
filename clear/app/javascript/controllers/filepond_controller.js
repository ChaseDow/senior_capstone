import { Controller } from "@hotwired/stimulus"
import * as FilePond from "filepond"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    if (!this.hasInputTarget) return
    if (this.pond) return

    this.element.classList.remove("filepond-ready")
    this._beforeCache = () => this.teardown()
    document.addEventListener("turbo:before-cache", this._beforeCache)
    this.pond = FilePond.create(this.inputTarget, {
      allowMultiple: false,
      maxFiles: 1,
      storeAsFile: true,
      credits: false,
      acceptedFileTypes: [
        "application/pdf",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/msword"
      ],
      labelIdle: "Drag & Drop your file or <span class=\"filepond--label-action\">Browse</span>",
      oninit: () => this.element.classList.add("filepond-ready")
    })
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this._beforeCache)
    this._beforeCache = null
    this.teardown()
  }

  teardown() {
    if (!this.pond) return
    this.pond.destroy()
    this.pond = null
    this.element.classList.remove("filepond-ready")
  }
}
