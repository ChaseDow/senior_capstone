import { Controller } from "@hotwired/stimulus"

const CONFIGURED_TYPES = new Set(["stat", "progress"])

export default class extends Controller {
  static targets = ["panel", "backdrop", "body"]

  open() {
    this._showCards()
    this.panelTarget.style.transform = "translateX(0)"
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.style.transform = "translateX(100%)"
    this.backdropTarget.classList.add("hidden")
  }

  selectWidget(event) {
    const card = event.currentTarget
    const config = {
      widgetType: card.dataset.widgetType,
      label:      card.dataset.widgetLabel,
      w:          parseInt(card.dataset.widgetW || 4),
      h:          parseInt(card.dataset.widgetH || 3),
    }

    if (CONFIGURED_TYPES.has(config.widgetType)) {
      this._showConfigForm(config)
    } else {
      window.dispatchEvent(new CustomEvent("widget:add", { detail: config }))
      this.close()
    }
  }

  // ── Card / form switching ─────────────────────────────────────────────────

  _showCards() {
    if (this._cardHTML) this.bodyTarget.innerHTML = this._cardHTML
  }

  _saveCardHTML() {
    if (!this._cardHTML) this._cardHTML = this.bodyTarget.innerHTML
  }

  _showConfigForm(config) {
    this._saveCardHTML()
    const isProgress = config.widgetType === "progress"

    this.bodyTarget.innerHTML = `
      <div style="padding:4px 0;">
        <button class="cfg-back" style="background:none;border:none;color:var(--studs-accent,#6366f1);
                font-size:13px;cursor:pointer;padding:0;margin-bottom:16px;">← Back</button>
        <div style="font-size:15px;font-weight:600;color:#f4f4f5;margin-bottom:16px;">
          Configure ${isProgress ? "Progress Bar" : "Stat Card"}
        </div>

        <div id="cfg-error" style="display:none;margin-bottom:12px;padding:10px;border-radius:8px;
             font-size:12px;color:#fca5a5;background:rgba(127,29,29,0.3);
             border:1px solid rgba(239,68,68,0.3);"></div>

        <form data-widget-type="${config.widgetType}" style="display:flex;flex-direction:column;gap:14px;">

          <div>
            <label style="font-size:12px;font-weight:500;color:#a1a1aa;display:block;margin-bottom:6px;">
              Title <span style="color:#52525b;">(optional)</span>
            </label>
            <input name="title" type="text" autocomplete="off"
                   placeholder="e.g. Study Hours This Week"
                   style="width:100%;padding:8px 10px;background:rgba(255,255,255,0.05);
                          border:1px solid var(--studs-border,#3f3f46);border-radius:8px;
                          color:#f4f4f5;font-size:13px;box-sizing:border-box;outline:none;"/>
          </div>

          <div>
            <label style="font-size:12px;font-weight:500;color:#a1a1aa;display:block;margin-bottom:6px;">
              Source type <span style="color:#ef4444;">*</span>
            </label>
            <select name="source_type" id="cfg-source-type"
                    style="width:100%;padding:8px 10px;background:var(--studs-sidebar-bg,#18181b);
                           border:1px solid var(--studs-border,#3f3f46);border-radius:8px;
                           color:#f4f4f5;font-size:13px;box-sizing:border-box;">
              <option value="">— choose type —</option>
              <option value="Event">Events</option>
              <option value="Course">Courses</option>
              <option value="WorkShift">Work Shifts</option>
            </select>
          </div>

          <div id="cfg-item-field" style="display:none;">
            <label style="font-size:12px;font-weight:500;color:#a1a1aa;display:block;margin-bottom:6px;">
              Specific item <span style="color:#52525b;">(optional)</span>
            </label>
            <select name="source_id" id="cfg-source-id"
                    style="width:100%;padding:8px 10px;background:var(--studs-sidebar-bg,#18181b);
                           border:1px solid var(--studs-border,#3f3f46);border-radius:8px;
                           color:#f4f4f5;font-size:13px;box-sizing:border-box;">
              <option value="">All trackable items</option>
            </select>
          </div>

          <div>
            <label style="font-size:12px;font-weight:500;color:#a1a1aa;display:block;margin-bottom:6px;">
              Metric <span style="color:#ef4444;">*</span>
            </label>
            <select name="metric"
                    style="width:100%;padding:8px 10px;background:var(--studs-sidebar-bg,#18181b);
                           border:1px solid var(--studs-border,#3f3f46);border-radius:8px;
                           color:#f4f4f5;font-size:13px;box-sizing:border-box;">
              <option value="">— choose metric —</option>
              <option value="count">Count (number of items)</option>
              <option value="duration_hours">Total Hours</option>
            </select>
          </div>

          <div>
            <label style="font-size:12px;font-weight:500;color:#a1a1aa;display:block;margin-bottom:6px;">
              Period
            </label>
            <select name="period"
                    style="width:100%;padding:8px 10px;background:var(--studs-sidebar-bg,#18181b);
                           border:1px solid var(--studs-border,#3f3f46);border-radius:8px;
                           color:#f4f4f5;font-size:13px;box-sizing:border-box;">
              <option value="week">This Week</option>
              <option value="month">This Month</option>
              <option value="all_time">All Time</option>
            </select>
          </div>

          ${isProgress ? `
          <div>
            <label style="font-size:12px;font-weight:500;color:#a1a1aa;display:block;margin-bottom:6px;">
              Goal <span style="color:#ef4444;">*</span>
            </label>
            <input name="goal" type="number" min="0.5" step="0.5"
                   placeholder="e.g. 20"
                   style="width:100%;padding:8px 10px;background:rgba(255,255,255,0.05);
                          border:1px solid var(--studs-border,#3f3f46);border-radius:8px;
                          color:#f4f4f5;font-size:13px;box-sizing:border-box;outline:none;"/>
          </div>` : ""}

          <button type="button" class="cfg-submit"
                  style="padding:10px;background:var(--studs-accent,#6366f1);color:white;
                         border:none;border-radius:8px;font-size:13px;font-weight:600;
                         cursor:pointer;margin-top:4px;">
            Add Widget
          </button>
        </form>
      </div>`

    this.bodyTarget.querySelector(".cfg-back")
      .addEventListener("click", () => this._showCards())

    this.bodyTarget.querySelector("#cfg-source-type")
      .addEventListener("change", e => this._loadItems(e.target.value))

    this.bodyTarget.querySelector(".cfg-submit")
      .addEventListener("click", () => this._submitConfig())
  }

  // ── Item loader ───────────────────────────────────────────────────────────

  async _loadItems(sourceType) {
    const field  = this.bodyTarget.querySelector("#cfg-item-field")
    const select = this.bodyTarget.querySelector("#cfg-source-id")
    if (!field || !select) return

    field.style.display = "none"
    select.innerHTML = '<option value="">All trackable items</option>'
    if (!sourceType) return

    try {
      const res = await fetch(`/analytics/widget_items?source_type=${encodeURIComponent(sourceType)}`, {
        headers: { Accept: "application/json" },
      })
      if (!res.ok) return
      const items = await res.json()
      items.forEach(item => {
        const opt = document.createElement("option")
        opt.value = item.id
        opt.textContent = item.name
        select.appendChild(opt)
      })
      if (items.length > 0) field.style.display = ""
    } catch (e) {
      console.error("[widget-drawer] failed to load items:", e)
    }
  }

  // ── Config submit ─────────────────────────────────────────────────────────

  async _submitConfig() {
    const form    = this.bodyTarget.querySelector("form")
    const errEl   = this.bodyTarget.querySelector("#cfg-error")
    const btn     = this.bodyTarget.querySelector(".cfg-submit")
    const type    = form.dataset.widgetType
    const source  = form.elements.source_type?.value || ""
    const metric  = form.elements.metric?.value      || ""

    if (!source) { this._showError(errEl, "Please choose a source type."); return }
    if (!metric) { this._showError(errEl, "Please choose a metric.");       return }
    if (type === "progress" && !form.elements.goal?.value) {
      this._showError(errEl, "Please enter a goal."); return
    }

    btn.disabled    = true
    btn.textContent = "Adding…"
    if (errEl) errEl.style.display = "none"

    const sourceId = form.elements.source_id?.value || null
    const payload  = {
      widget_config: {
        widget_type: type,
        title:       form.elements.title?.value?.trim() || null,
        source_type: source,
        source_id:   sourceId ? parseInt(sourceId, 10) : null,
        metric,
        period:      form.elements.period?.value || "week",
        goal:        form.elements.goal?.value   || null,
      }
    }

    try {
      const res = await fetch("/widget_configs", {
        method:  "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken() },
        body:    JSON.stringify(payload),
      })
      if (!res.ok) throw new Error(await res.text())
      const data = await res.json()
      // data comes from as_widget_json — map it to the widget:add shape
      window.dispatchEvent(new CustomEvent("widget:add", { detail: {
        widgetType: data.type,
        label:      data.title,
        w:          data.w,
        h:          data.h,
        serverData: data,   // pass full server payload for real values
      }}))
      this.close()
    } catch (e) {
      console.error("[widget-drawer] submit error:", e)
      this._showError(errEl, `Error: ${e.message}`)
      btn.disabled    = false
      btn.textContent = "Add Widget"
    }
  }

  _showError(el, msg) {
    if (el) { el.textContent = msg; el.style.display = "block" }
    else alert(msg)
  }
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content ?? ""
}
