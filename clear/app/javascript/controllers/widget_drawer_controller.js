import { Controller } from "@hotwired/stimulus"

const CONFIGURED_TYPES = new Set(["stat", "progress"])
const TRACKING_TYPES   = new Set(["tracking-card"])

const SEARCH_ENDPOINTS = {
  Event:      "/api/search/events",
  Course:     "/api/search/courses",
  CourseItem: "/api/search/course_items",
  WorkShift:  "/api/search/work_shifts",
}

const RESOURCE_LABELS = {
  Event:      "Event",
  Course:     "Course",
  CourseItem: "Course Item",
  WorkShift:  "Work Shift",
}

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
    this._currentResourceType = null
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
    } else if (TRACKING_TYPES.has(config.widgetType)) {
      this._showTrackingTypeSelect()
    } else {
      window.dispatchEvent(new CustomEvent("widget:add", { detail: config }))
      this.close()
    }
  }

  // ── Tracking card flow ────────────────────────────────────────────────────

  _showTrackingTypeSelect() {
    this._saveCardHTML()
    this.bodyTarget.style.display = "flex"
    this.bodyTarget.style.flexDirection = "column"
    this.bodyTarget.style.gap = "0"

    this.bodyTarget.innerHTML = `
      <div style="padding:4px 0;">
        <button class="cfg-back" style="background:none;border:none;color:var(--studs-accent,#6366f1);
                font-size:13px;cursor:pointer;padding:0;margin-bottom:16px;">← Back</button>
        <div style="font-size:15px;font-weight:600;color:#f4f4f5;margin-bottom:4px;">
          What are you tracking?
        </div>
        <div style="font-size:12px;color:#71717a;margin-bottom:16px;">
          Pick a type to search for a specific item
        </div>
        <div style="display:flex;flex-direction:column;gap:10px;">
          ${["Event", "Course", "CourseItem", "WorkShift"].map(type => `
            <button class="track-type-btn"
                    data-resource-type="${type}"
                    style="padding:12px 14px;background:var(--studs-panel-bg,#1e1e2e);
                           border:1px solid var(--studs-border,#3f3f46);border-radius:10px;
                           color:#e4e4e7;font-size:13px;font-weight:500;text-align:left;
                           cursor:pointer;transition:border-color 0.15s;"
                    onmouseover="this.style.borderColor='var(--studs-accent,#6366f1)'"
                    onmouseout="this.style.borderColor='var(--studs-border,#3f3f46)'">
              ${RESOURCE_LABELS[type]}
            </button>
          `).join("")}
        </div>
      </div>`

    this.bodyTarget.querySelector(".cfg-back")
      .addEventListener("click", () => this._showCards())

    this.bodyTarget.querySelectorAll(".track-type-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        this._showTrackingSearch(btn.dataset.resourceType)
      })
    })
  }

  _showTrackingSearch(resourceType) {
    this._currentResourceType = resourceType
    const label = RESOURCE_LABELS[resourceType]

    this.bodyTarget.innerHTML = `
      <div style="padding:4px 0;display:flex;flex-direction:column;height:100%;">
        <button class="cfg-back" style="background:none;border:none;color:var(--studs-accent,#6366f1);
                font-size:13px;cursor:pointer;padding:0;margin-bottom:16px;">← Back</button>
        <div style="font-size:15px;font-weight:600;color:#f4f4f5;margin-bottom:4px;">
          Search ${label}s
        </div>
        <div style="font-size:12px;color:#71717a;margin-bottom:12px;">
          Click a result to add it to your dashboard
        </div>

        <input id="tracking-search-input" type="text" autocomplete="off"
               placeholder="Search ${label}s…"
               style="width:100%;padding:8px 10px;background:rgba(255,255,255,0.05);
                      border:1px solid var(--studs-border,#3f3f46);border-radius:8px;
                      color:#f4f4f5;font-size:13px;box-sizing:border-box;outline:none;
                      margin-bottom:10px;"/>

        <div id="tracking-search-results"
             style="flex:1;overflow-y:auto;border-radius:8px;">
          <p style="color:#71717a;font-size:12px;padding:8px 0;">Loading…</p>
        </div>
      </div>`

    this.bodyTarget.querySelector(".cfg-back")
      .addEventListener("click", () => this._showTrackingTypeSelect())

    const input = this.bodyTarget.querySelector("#tracking-search-input")
    input.addEventListener("input", e => {
      clearTimeout(this._searchTimeout)
      this._searchTimeout = setTimeout(() => this._runSearch(e.target.value), 300)
    })
    input.focus()

    this._runSearch("")
  }

  _runSearch(query) {
    const resultsEl = this.bodyTarget.querySelector("#tracking-search-results")
    if (!resultsEl) return

    const endpoint = SEARCH_ENDPOINTS[this._currentResourceType]
    if (!endpoint) return

    fetch(`${endpoint}?q=${encodeURIComponent(query)}`, {
      credentials: "same-origin",
      headers: { "Accept": "application/json", "X-CSRF-Token": csrfToken() },
    })
      .then(r => r.json())
      .then(results => this._renderSearchResults(resultsEl, results))
      .catch(() => {
        resultsEl.innerHTML = '<p style="color:#f87171;font-size:12px;padding:8px 0;">Failed to load results</p>'
      })
  }

  _renderSearchResults(container, results) {
    if (results.length === 0) {
      container.innerHTML = '<p style="color:#71717a;font-size:12px;padding:8px 0;">No results found</p>'
      return
    }

    container.innerHTML = results.map(r => `
      <div class="search-result-item"
           data-resource-id="${r.id}"
           data-resource-label="${escAttr(r.label)}"
           style="padding:10px 12px;cursor:pointer;border-radius:6px;
                  font-size:13px;color:#e4e4e7;transition:background 0.15s;"
           onmouseover="this.style.background='rgba(99,102,241,0.12)'"
           onmouseout="this.style.background='transparent'">
        ${esc(r.label)}
      </div>
    `).join("")

    container.querySelectorAll(".search-result-item").forEach(el => {
      el.addEventListener("click", () => {
        if (this._currentResourceType === "Event") {
          this._showGoalStep(el.dataset.resourceId, el.dataset.resourceLabel)
        } else {
          this._addTrackingEntry(el.dataset.resourceId, el.dataset.resourceLabel)
        }
      })
    })
  }

  // Step shown only for Events: ask for a goal before saving
  _showGoalStep(resourceId, resourceLabel) {
    this.bodyTarget.innerHTML = `
      <div style="padding:4px 0;">
        <button class="cfg-back" style="background:none;border:none;color:var(--studs-accent,#6366f1);
                font-size:13px;cursor:pointer;padding:0;margin-bottom:16px;">← Back</button>
        <div style="font-size:15px;font-weight:600;color:#f4f4f5;margin-bottom:4px;">
          Set a goal for <span style="color:var(--studs-accent,#6366f1);">${esc(resourceLabel)}</span>
        </div>
        <div style="font-size:12px;color:#71717a;margin-bottom:20px;">
          How many hours do you want to complete?
        </div>

        <div style="display:flex;flex-direction:column;gap:14px;">
          <div>
            <label style="font-size:12px;font-weight:500;color:#a1a1aa;display:block;margin-bottom:6px;">
              Goal (hours)
            </label>
            <input id="goal-hours-input" type="number" value="10" min="1" max="1000" step="0.5"
                   autocomplete="off"
                   style="width:100%;padding:8px 10px;background:rgba(255,255,255,0.05);
                          border:1px solid var(--studs-border,#3f3f46);border-radius:8px;
                          color:#f4f4f5;font-size:13px;box-sizing:border-box;outline:none;"/>
          </div>

          <button id="goal-confirm-btn"
                  style="padding:10px;background:var(--studs-accent,#6366f1);color:white;
                         border:none;border-radius:8px;font-size:13px;font-weight:600;
                         cursor:pointer;">
            Add Widget
          </button>
        </div>
      </div>`

    this.bodyTarget.querySelector(".cfg-back")
      .addEventListener("click", () => this._showTrackingSearch("Event"))

    this.bodyTarget.querySelector("#goal-confirm-btn")
      .addEventListener("click", () => {
        const goalHours = parseFloat(
          this.bodyTarget.querySelector("#goal-hours-input").value || "10"
        )
        this._addTrackingEntry(resourceId, resourceLabel, goalHours)
      })

    // Focus the input
    requestAnimationFrame(() => {
      this.bodyTarget.querySelector("#goal-hours-input")?.focus()
    })
  }

  _addTrackingEntry(resourceId, resourceLabel, goalHours = null) {
    fetch("/tracking_entries", {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({
        tracking_entry: {
          trackable_type: this._currentResourceType,
          trackable_id:   resourceId,
        },
      }),
    })
      .then(async r => {
        if (!r.ok) {
          const body = await r.json().catch(() => ({}))
          const msg = body.errors?.join(", ") || "Failed to add widget"
          alert(msg)
          return
        }
        return r.json()
      })
      .then(entry => {
        if (!entry) return
        window.dispatchEvent(new CustomEvent("widget:add", {
          detail: {
            entryId:       entry.id,
            widgetType:    "tracking-card",
            resourceType:  entry.trackable_type,
            resourceId:    entry.trackable_id,
            resourceLabel: entry.trackable_label,
            completed:     entry.completed,
            completedAt:   entry.completed_at,
            goalHours:     goalHours,
            w: 4,
            h: 3,
          },
        }))
        this.close()
      })
      .catch(() => alert("Failed to add widget. Please try again."))
  }

  // ── Card / form switching ─────────────────────────────────────────────────

  _showCards() {
    this.bodyTarget.style.display = ""
    this.bodyTarget.style.flexDirection = ""
    this.bodyTarget.style.gap = ""
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
      window.dispatchEvent(new CustomEvent("widget:add", { detail: {
        widgetType: data.type,
        label:      data.title,
        w:          data.w,
        h:          data.h,
        serverData: data,
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

function esc(str) {
  return String(str)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

function escAttr(str) {
  return String(str).replace(/"/g, "&quot;").replace(/'/g, "&#39;")
}
