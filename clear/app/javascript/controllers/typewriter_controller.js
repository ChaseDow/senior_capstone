import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
        text: String,
        speed: { type: Number, default: 12 }
    }

    connect() {
        const full = this.textValue || ""
        if (!full.length) return

        const messages = document.getElementById("ai_chat_messages")
        const keepInView = () => {
            if (messages) messages.scrollTop = messages.scrollHeight
        }

        this.element.textContent = ""
        keepInView()

        let i = 0
        const tick = () => {
            if (i >= full.length) return
            this.element.textContent += full[i]
            i += 1
            keepInView()
            window.setTimeout(tick, this.speedValue)
        }

        tick()
    }
}
