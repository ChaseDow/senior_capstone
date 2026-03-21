import { Controller } from "@hotwired/stimulus"
import Cropper from "cropperjs"
import "cropperjs/dist/cropper.css"

export default class extends Controller {
  static targets = ["form", "file", "image", "preview"]

  connect() {
    this._active = true
    this.cropper = null
    this.objectUrl = null

    if (this.imageTarget.src && !this.imageTarget.classList.contains("hidden")) {
      if (this.imageTarget.complete && this.imageTarget.naturalWidth > 0) {
        this.initCropper()
      } else {
        this.imageTarget.addEventListener("load", this._onInitialLoad)
      }
    }
  }

  _onInitialLoad = () => {
    if (!this._active) return
    this.imageTarget.removeEventListener("load", this._onInitialLoad)
    this.initCropper()
  }

  initCropper() {
    if (!this._active) return
    if (!this.hasImageTarget || !this.hasPreviewTarget) return

    if (this.cropper) this.cropper.destroy()

    this.cropper = new Cropper(this.imageTarget, {
      aspectRatio: 1,
      viewMode: 1,
      autoCropArea: 1,
      background: false,
      responsive: true,
      preview: this.previewTarget,
    })
  }

  fileChanged() {
    if (!this._active) return
    this._croppedReady = false
    const file = this.fileTarget.files?.[0]
    if (!file) return

    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
      this.objectUrl = null
    }

    this.objectUrl = URL.createObjectURL(file)
    this.imageTarget.src = this.objectUrl
    this.imageTarget.classList.remove("hidden")
    this.imageTarget.onload = null

    this.imageTarget.onload = () => {
      if (!this._active) return
      this.initCropper()
    }
  }


  zoomIn() {
    if (!this.cropper) return
    this.cropper.zoom(0.1)
  }

  zoomOut() {
    if (!this.cropper) return
    this.cropper.zoom(-0.1)
  }

  reset() {
    if (!this.cropper) return
    this.cropper.reset()
  }

  submitCropped(event) {
    if (!this._active) return
    if (this._croppedReady) return

    const hasNewFile = this.fileTarget.files?.length > 0
    if (!hasNewFile) return
    if (!this.cropper) return

    event.preventDefault()

    const form = this.formTarget
    const canvas = this.cropper.getCroppedCanvas({ width: 512, height: 512 })

    canvas.toBlob((blob) => {
      if (!blob) return

      const file = new File([blob], "avatar.jpg", { type: "image/jpeg" })
      const dt = new DataTransfer()
      dt.items.add(file)
      this.fileTarget.files = dt.files

      this._croppedReady = true
      form.requestSubmit()
    }, "image/jpeg", 0.9)
  }

  disconnect() {
    this._active = false
    if (this.hasImageTarget) {
      this.imageTarget.removeEventListener("load", this._onInitialLoad)
      this.imageTarget.onload = null
    }
    if (this.cropper) this.cropper.destroy()
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
  }
}
