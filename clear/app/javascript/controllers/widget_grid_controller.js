import { Controller } from "@hotwired/stimulus"
import GridStack from "gridstack/dist/gridstack-all.js"

export default class extends Controller {
  static targets = ["grid"]

  connect() {
    this._gridReady  = false
    this._pendingWidgets = []

    this.boundAddWidget = this.addWidget.bind(this)
    window.addEventListener("widget:add", this.boundAddWidget)

    // Defer GridStack init until the Personal tab is visible.
    // Calling GridStack.init() on a display:none element gives 0px column widths,
    // making every widget invisible or collapsed.
    this._onTabActivated = (e) => {
      if (e.detail?.tab !== "person") return
      if (!this._gridReady) {
        this._initGrid()
      } else if (this.grid) {
        // Already initialized — force GridStack to recalculate layout.
        requestAnimationFrame(() => window.dispatchEvent(new Event("resize")))
      }
    }
    window.addEventListener("analytics:tab-activated", this._onTabActivated)

    // If the Personal tab is already active on load (user refreshed while on it),
    // init immediately rather than waiting for the event.
    const savedTab = localStorage.getItem("analytics:active-tab") || "overview"
    if (savedTab === "person") {
      this._initGrid()
    }
  }

  _initGrid() {
    if (this._gridReady) return

    this.grid = GridStack.init(
      { cellHeight: 80, minRow: 4, animate: true },
      this.gridTarget
    )

    this._gridReady = true
    this.grid.on("dragstop resizestop", () => this.saveLayout())

    this.restoreLayout()
    this.loadExistingEntries()

    // Flush any widget:add events that arrived before the grid was ready.
    this._pendingWidgets.forEach(config => this._renderWidget(config))
    this._pendingWidgets = []
  }

  disconnect() {
    window.removeEventListener("widget:add", this.boundAddWidget)
    window.removeEventListener("analytics:tab-activated", this._onTabActivated)
    if (this.grid) this.grid.destroy(false)
    document.querySelector(".occ-panel")?.remove()
    document.querySelector(".occ-backdrop")?.remove()
  }

  // ── Add widget ────────────────────────────────────────────────────────────

  addWidget(event) {
    const config = event.detail
    console.log("[widget-grid] addWidget received:", config)

    // Buffer the widget if the grid isn't initialized yet (tab not visible).
    if (!this._gridReady) {
      this._pendingWidgets.push(config)
      return
    }

    this._renderWidget(config)
  }

  _renderWidget(config) {

    const item = document.createElement("div")
    item.className = "grid-stack-item"
    item.setAttribute("gs-w", config.w || 4)
    item.setAttribute("gs-h", config.h || 3)
    item.dataset.widgetType  = config.widgetType || ""
    item.dataset.widgetLabel = config.label || config.resourceLabel || ""

    if (config.entryId) {
      item.dataset.entryId    = config.entryId
      item.dataset.resourceId = config.resourceId || ""

      const pos = this._trackingPositions()[String(config.entryId)]
      if (pos) {
        item.setAttribute("gs-x", pos.x)
        item.setAttribute("gs-y", pos.y)
        item.setAttribute("gs-w", pos.w)
        item.setAttribute("gs-h", pos.h)
        // Prefer stored goalHours; fall back to what came in the event
        config.goalHours = pos.goalHours ?? config.goalHours
      }

      if (config.goalHours != null) item.dataset.goalHours = config.goalHours
    }

    const inner = document.createElement("div")
    inner.className = "grid-stack-item-content"
    inner.innerHTML = this.renderWidgetBody(config)

    item.appendChild(inner)
    this.gridTarget.appendChild(item)
    this.grid.makeWidget(item)
    this.saveLayout()

    // For Event tracking cards, async-populate the progress bar after the
    // element is in the DOM (needs the element to be visible to find it).
    if (config.widgetType === "tracking-card" && config.resourceType === "Event" && config.entryId) {
      requestAnimationFrame(() => {
        this._loadEventCard(config.entryId, config.resourceId, config.goalHours ?? 10)
      })
    }
  }

  // ── Remove widget ─────────────────────────────────────────────────────────

  removeWidget(event) {
    const item = event.target.closest(".grid-stack-item")
    if (!item) return

    const entryId = item.dataset.entryId
    if (entryId) {
      fetch(`/tracking_entries/${entryId}`, {
        method: "DELETE",
        credentials: "same-origin",
        headers: { "X-CSRF-Token": csrfToken() },
      }).catch(e => console.error("[widget-grid] failed to delete tracking entry:", e))

      const positions = this._trackingPositions()
      delete positions[String(entryId)]
      localStorage.setItem("tracking-positions", JSON.stringify(positions))
    }

    this.grid.removeWidget(item)
    this.saveLayout()
  }

  // ── Checkbox toggle (non-Event tracking cards) ────────────────────────────

  toggleComplete(event) {
    const checkbox = event.target
    const entryId  = checkbox.dataset.entryId
    const completed = checkbox.checked

    fetch(`/tracking_entries/${entryId}`, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ completed }),
    })
      .then(r => r.json())
      .then(entry => {
        const label = this.element.querySelector(
          `.completed-at-label[data-entry-id="${entryId}"]`
        )
        if (label) {
          label.textContent = entry.completed_at
            ? `Completed ${new Date(entry.completed_at).toLocaleDateString()}`
            : "Not yet completed"
        }
      })
      .catch(() => {
        checkbox.checked = !completed
        alert("Failed to save. Please try again.")
      })
  }

  // ── Event occurrence handlers ─────────────────────────────────────────────

  openOccurrences(event) {
    const btn       = event.currentTarget
    const eventId   = btn.dataset.eventId
    const entryId   = btn.dataset.entryId
    const goalHours = parseFloat(btn.dataset.goalHours || "10")

    fetch(`/event_occurrences?event_id=${eventId}`, {
      credentials: "same-origin",
      headers: { "Accept": "application/json", "X-CSRF-Token": csrfToken() },
    })
      .then(r => r.json())
      .then(occurrences => this._showOccurrencesPanel(eventId, entryId, goalHours, occurrences))
      .catch(() => alert("Failed to load sessions."))
  }

  _showOccurrencesPanel(eventId, entryId, goalHours, occurrences) {
    document.querySelector(".occ-panel")?.remove()
    document.querySelector(".occ-backdrop")?.remove()

    const backdrop = document.createElement("div")
    backdrop.className = "occ-backdrop"
    backdrop.style.cssText = [
      "position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:400;",
      "backdrop-filter:blur(2px);"
    ].join("")
    backdrop.addEventListener("click", () => this._closeOccurrencesPanel())

    const label = this.element.querySelector(`[data-entry-id="${entryId}"]`)
      ?.dataset.widgetLabel || "Sessions"

    const panel = document.createElement("div")
    panel.className = "occ-panel"
    panel.style.cssText = [
      "position:fixed;top:0;right:0;height:100vh;width:380px;",
      "background:var(--studs-sidebar-bg,#18181b);",
      "border-left:1px solid var(--studs-border,#3f3f46);",
      "z-index:401;box-shadow:-4px 0 24px rgba(0,0,0,0.4);",
      "display:flex;flex-direction:column;overflow:hidden;"
    ].join("")

    const doneCount = occurrences.filter(o => o.completed).length
    const totalHrs  = occurrences.reduce((s, o) => s + (parseFloat(o.duration_hours) || 0), 0)
    const doneHrs   = occurrences
      .filter(o => o.completed)
      .reduce((s, o) => s + (parseFloat(o.duration_hours) || 0), 0)

    panel.innerHTML = `
      <div style="display:flex;align-items:center;justify-content:space-between;
                  padding:16px 20px;border-bottom:1px solid var(--studs-border,#3f3f46);
                  flex-shrink:0;">
        <div>
          <div style="font-size:15px;font-weight:600;color:#f4f4f5;">${esc(label)}</div>
          <div style="font-size:11px;color:#71717a;margin-top:2px;">
            ${doneCount} of ${occurrences.length} sessions &bull; ${doneHrs.toFixed(1)}h of ${totalHrs.toFixed(1)}h
          </div>
        </div>
        <button class="occ-close-btn"
                style="width:32px;height:32px;display:flex;align-items:center;
                       justify-content:center;border-radius:8px;border:none;
                       background:none;color:#71717a;font-size:22px;cursor:pointer;">
          &times;
        </button>
      </div>

      <div style="flex:1;overflow-y:auto;padding:8px 16px;">
        ${occurrences.length === 0
          ? '<p style="color:#71717a;font-size:13px;padding:20px 0;text-align:center;">No past sessions found</p>'
          : occurrences.map(o => `
            <label style="display:flex;align-items:center;gap:12px;padding:10px 0;
                          border-bottom:1px solid rgba(255,255,255,0.05);cursor:pointer;">
              <input type="checkbox"
                     class="occ-checkbox"
                     data-occurrence-id="${o.id}"
                     ${o.completed ? "checked" : ""}
                     style="width:16px;height:16px;flex-shrink:0;cursor:pointer;
                            accent-color:var(--studs-accent,#6366f1);">
              <div style="flex:1;min-width:0;">
                <div style="font-size:13px;font-weight:500;color:#e4e4e7;">
                  ${esc(o.day_of_week)}
                </div>
                <div style="font-size:11px;color:#71717a;">
                  ${esc(o.occurs_on_label)}
                  ${o.duration_hours ? `&bull; ${parseFloat(o.duration_hours).toFixed(1)}h` : ""}
                </div>
              </div>
              ${o.completed
                ? `<span style="font-size:10px;color:#34d399;font-weight:600;">DONE</span>`
                : `<span style="font-size:10px;color:#52525b;">-</span>`}
            </label>
          `).join("")}
      </div>

      <div style="padding:12px 20px;border-top:1px solid var(--studs-border,#3f3f46);
                  flex-shrink:0;text-align:center;">
        <p style="font-size:11px;color:#52525b;">
          Check sessions you've completed — your progress bar updates automatically
        </p>
      </div>`

    document.body.appendChild(backdrop)
    document.body.appendChild(panel)

    panel.querySelector(".occ-close-btn")
      .addEventListener("click", () => this._closeOccurrencesPanel())

    panel.querySelectorAll(".occ-checkbox").forEach(cb => {
      cb.addEventListener("change", () => {
        this._toggleOccurrence(
          cb.dataset.occurrenceId,
          cb.checked,
          eventId,
          entryId,
          goalHours,
          panel
        )
      })
    })
  }

  _closeOccurrencesPanel() {
    document.querySelector(".occ-panel")?.remove()
    document.querySelector(".occ-backdrop")?.remove()
  }

  _toggleOccurrence(occurrenceId, completed, eventId, entryId, goalHours, panel) {
    fetch(`/event_occurrences/${occurrenceId}`, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ completed }),
    })
      .then(r => r.json())
      .then(result => {
        // Update the "DONE" / "-" label in the panel
        const cb   = panel.querySelector(`[data-occurrence-id="${occurrenceId}"]`)
        const badge = cb?.closest("label")?.querySelector("span:last-child")
        if (badge) {
          badge.style.color = result.completed ? "#34d399" : "#52525b"
          badge.textContent = result.completed ? "DONE" : "-"
        }
        // Update running totals in header
        this._refreshPanelHeader(panel)
        // Refresh the progress bar widget on the grid
        this._loadEventCard(entryId, eventId, goalHours)
      })
      .catch(() => {
        const cb = panel.querySelector(`[data-occurrence-id="${occurrenceId}"]`)
        if (cb) cb.checked = !completed
        alert("Failed to save. Please try again.")
      })
  }

  _refreshPanelHeader(panel) {
    const checkboxes = panel.querySelectorAll(".occ-checkbox")
    let doneCount = 0, totalCount = 0
    checkboxes.forEach(cb => { totalCount++; if (cb.checked) doneCount++ })
    const subtitle = panel.querySelector("div > div > div:last-child")
    if (subtitle) {
      subtitle.textContent = `${doneCount} of ${totalCount} sessions`
    }
  }

  // ── Event progress card — async fetch + render ────────────────────────────

  _loadEventCard(entryId, eventId, goalHours) {
    const item       = this.element.querySelector(`.grid-stack-item[data-entry-id="${entryId}"]`)
    const progressEl = item?.querySelector(".event-progress-content")
    if (!progressEl) return

    progressEl.innerHTML = '<p style="color:#71717a;font-size:11px;">Loading…</p>'

    fetch(`/event_occurrences/summary?event_id=${eventId}&goal_hours=${goalHours}`, {
      credentials: "same-origin",
      headers: { "Accept": "application/json", "X-CSRF-Token": csrfToken() },
    })
      .then(r => r.json())
      .then(data => {
        progressEl.innerHTML = this._eventProgressHtml(entryId, eventId, goalHours, data)
      })
      .catch(() => {
        progressEl.innerHTML = '<p style="color:#f87171;font-size:11px;">Failed to load</p>'
      })
  }

  _eventProgressHtml(entryId, eventId, goalHours, data) {
    const hoursColor   = data.pct_hours  >= 80 ? "#34d399" : data.pct_hours  >= 50 ? "var(--studs-accent,#6366f1)" : "#f59e0b"
    const sessColor    = data.pct_events >= 80 ? "#34d399" : data.pct_events >= 50 ? "var(--studs-accent,#6366f1)" : "#f59e0b"

    return `
      <div style="display:flex;flex-direction:column;gap:10px;height:100%;justify-content:center;">

        <div style="display:flex;justify-content:space-between;align-items:baseline;">
          <span style="font-size:11px;color:#71717a;">
            ${data.done_hours}h completed
          </span>
          <span style="font-size:11px;font-weight:600;color:${hoursColor};">
            ${data.pct_hours}% of ${data.goal_hours}h goal
          </span>
        </div>

        <div style="position:relative;height:10px;background:rgba(255,255,255,0.08);
                    border-radius:999px;overflow:hidden;">
          <div style="position:absolute;inset-y:0;left:0;width:${data.pct_hours}%;
                      background:${hoursColor};border-radius:999px;
                      transition:width 0.6s ease;"></div>
        </div>

        <div style="display:flex;justify-content:space-between;align-items:center;
                    font-size:10px;color:#52525b;">
          <span>${data.done_count} / ${data.total_past} sessions done</span>
          <span style="color:${sessColor};font-weight:600;">${data.pct_events}%</span>
        </div>

        <div style="position:relative;height:6px;background:rgba(255,255,255,0.06);
                    border-radius:999px;overflow:hidden;">
          <div style="position:absolute;inset-y:0;left:0;width:${data.pct_events}%;
                      background:${sessColor};border-radius:999px;
                      transition:width 0.6s ease;"></div>
        </div>

        <button data-action="click->widget-grid#openOccurrences"
                data-event-id="${eventId}"
                data-entry-id="${entryId}"
                data-goal-hours="${goalHours}"
                style="font-size:11px;color:var(--studs-accent,#6366f1);background:none;
                       border:none;cursor:pointer;padding:0;text-align:left;
                       text-decoration:underline;margin-top:2px;">
          View all sessions →
        </button>
      </div>`
  }

  // ── Load existing entries from server ─────────────────────────────────────

  loadExistingEntries() {
    fetch("/tracking_entries", {
      credentials: "same-origin",
      headers: { "Accept": "application/json", "X-CSRF-Token": csrfToken() },
    })
      .then(r => r.json())
      .then(entries => {
        entries.forEach(entry => {
          const pos = this._trackingPositions()[String(entry.id)]
          this.addWidget({
            detail: {
              entryId:       entry.id,
              widgetType:    "tracking-card",
              resourceType:  entry.trackable_type,
              resourceId:    entry.trackable_id,
              resourceLabel: entry.trackable_label,
              completed:     entry.completed,
              completedAt:   entry.completed_at,
              goalHours:     pos?.goalHours ?? null,
              w: 4,
              h: 3,
            },
          })
        })
      })
      .catch(e => console.error("[widget-grid] Failed to load tracking entries:", e))
  }

  // ── Widget rendering ──────────────────────────────────────────────────────

  renderWidgetBody(config) {
    const title = esc(config.label || config.resourceLabel || config.widgetType || "Widget")

    return `
      <div style="position:absolute;inset:0;display:flex;flex-direction:column;
                  border-radius:10px;border:1px solid var(--studs-border,#3f3f46);
                  background:var(--studs-panel-bg,#1e1e2e);overflow:hidden;">
        <!-- header -->
        <div style="display:flex;align-items:center;justify-content:space-between;
                    padding:8px 12px;flex-shrink:0;
                    border-bottom:1px solid var(--studs-border,#3f3f46);
                    background:rgba(255,255,255,0.02);">
          <span style="font-size:11px;font-weight:600;color:#a1a1aa;
                       text-transform:uppercase;letter-spacing:0.05em;">${title}</span>
          <button data-action="click->widget-grid#removeWidget"
                  style="background:none;border:none;color:#52525b;font-size:18px;
                         line-height:1;cursor:pointer;padding:0 2px;">×</button>
        </div>
        <!-- body -->
        <div style="flex:1;min-height:0;padding:10px;overflow:hidden;">
          ${this._widgetContent(config.widgetType, config)}
        </div>
      </div>`
  }

  _widgetContent(type, config) {
    const d = config.serverData || config

    switch (type) {
      case "tracking-card":
        return this._trackingCardContent(config)

      case "stat": {
        const val       = d.value != null ? String(d.value) : "—"
        const metricLbl = { count: "items", duration_hours: "hrs" }[d.metric] || ""
        const periodLbl = { week: "this week", month: "this month", all_time: "all time" }[d.period] || ""
        const sub       = [metricLbl, periodLbl].filter(Boolean).join(" · ")
        return `
          <div style="display:flex;flex-direction:column;align-items:center;
                      justify-content:center;height:100%;text-align:center;gap:6px;">
            <div style="font-size:clamp(32px,5cqw,52px);font-weight:700;
                        color:#f4f4f5;line-height:1;">${esc(val)}</div>
            ${sub ? `<div style="font-size:11px;color:#71717a;">${esc(sub)}</div>` : ""}
          </div>`
      }

      case "progress": {
        const current = Number(d.current ?? d.value ?? 0)
        const goal    = Number(d.goal ?? 0)
        const pct     = d.pct ?? (goal > 0 ? Math.min(Math.round(current / goal * 100), 100) : 0)
        const color   = pct >= 80 ? "#34d399" : pct >= 50 ? "var(--studs-accent,#6366f1)" : "#f59e0b"
        const unitLbl = { count: "", duration_hours: " hrs" }[d.metric] || ""
        return `
          <div style="display:flex;flex-direction:column;justify-content:center;
                      height:100%;gap:10px;">
            <div style="display:flex;justify-content:space-between;font-size:11px;color:#71717a;">
              <span>${esc(String(current))}${unitLbl}</span>
              <span>goal: ${esc(String(goal))}${unitLbl}</span>
            </div>
            <div style="position:relative;height:12px;background:rgba(255,255,255,0.08);
                        border-radius:999px;overflow:hidden;">
              <div style="position:absolute;inset-y:0;left:0;width:${pct}%;
                          background:${color};border-radius:999px;
                          transition:width 0.6s ease;"></div>
            </div>
            <div style="display:flex;justify-content:flex-end;">
              <span style="font-size:16px;font-weight:700;color:${color};">${pct}%</span>
            </div>
          </div>`
      }

      case "line":
        return `<svg viewBox="0 0 200 80" style="width:100%;height:100%;"
                     preserveAspectRatio="none">
                  <polyline points="0,65 30,48 60,55 90,28 120,38 150,15 200,30"
                    fill="none" stroke="var(--studs-accent,#6366f1)" stroke-width="2.5"
                    stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"/>
                </svg>`

      case "bar":
        return `<svg viewBox="0 0 70 50" style="width:100%;height:100%;"
                     preserveAspectRatio="none">
                  ${[40,65,30,80,55,70,45].map((h, i) =>
                    `<rect x="${i*10+1}" y="${50 - h*0.5}" width="8" height="${h*0.5}"
                           rx="1" fill="var(--studs-accent,#6366f1)" opacity="${0.5 + h/200}"/>`
                  ).join("")}
                </svg>`

      case "pie":
        return `
          <div style="display:flex;align-items:center;justify-content:center;
                      gap:12px;height:100%;">
            <svg viewBox="0 0 42 42" style="width:min(80px,50%);height:min(80px,50%);
                 flex-shrink:0;transform:rotate(-90deg);">
              <circle cx="21" cy="21" r="15.9" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="5"/>
              <circle cx="21" cy="21" r="15.9" fill="none" stroke="#60a5fa" stroke-width="5"
                      stroke-dasharray="40 60"/>
              <circle cx="21" cy="21" r="15.9" fill="none" stroke="#34d399" stroke-width="5"
                      stroke-dasharray="25 75" stroke-dashoffset="-40"/>
              <circle cx="21" cy="21" r="15.9" fill="none" stroke="#a78bfa" stroke-width="5"
                      stroke-dasharray="20 80" stroke-dashoffset="-65"/>
              <circle cx="21" cy="21" r="15.9" fill="none" stroke="#fbbf24" stroke-width="5"
                      stroke-dasharray="15 85" stroke-dashoffset="-85"/>
            </svg>
            <div style="font-size:10px;color:#71717a;line-height:2;">
              <div>Events</div><div>Courses</div><div>Shifts</div>
            </div>
          </div>`

      case "area":
        return `<svg viewBox="0 0 200 80" style="width:100%;height:100%;"
                     preserveAspectRatio="none">
                  <path d="M0,65 L30,48 L60,55 L90,28 L120,38 L150,15 L200,30 L200,80 L0,80 Z"
                        fill="var(--studs-accent,#6366f1)" opacity="0.2"/>
                  <polyline points="0,65 30,48 60,55 90,28 120,38 150,15 200,30"
                    fill="none" stroke="var(--studs-accent,#6366f1)" stroke-width="2.5"
                    stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"/>
                </svg>`

      case "heatmap":
        return `<svg viewBox="0 0 260 56" style="width:100%;height:100%;"
                     preserveAspectRatio="xMinYMid meet">
                  ${heatmapRects()}
                </svg>`

      default:
        return `<div style="color:#71717a;font-size:11px;">${esc(type)}</div>`
    }
  }

  _trackingCardContent(config) {
    // Events get an async progress bar; everything else gets a checkbox.
    if (config.resourceType === "Event") {
      return `<div class="event-progress-content" style="height:100%;display:flex;align-items:center;">
                <p style="color:#71717a;font-size:11px;">Loading…</p>
              </div>`
    }

    const entryId      = config.entryId || ""
    const checkedAttr  = config.completed ? "checked" : ""
    const resourceType = esc(config.resourceType || "")
    const completedText = config.completedAt
      ? `Completed ${new Date(config.completedAt).toLocaleDateString()}`
      : "Not yet completed"

    return `
      <div style="padding:4px 2px;">
        <div style="font-size:11px;color:#71717a;margin-bottom:14px;line-height:1.4;">
          <span style="background:rgba(99,102,241,0.15);color:var(--studs-accent,#6366f1);
                       padding:2px 7px;border-radius:999px;font-weight:600;font-size:10px;">
            ${resourceType}
          </span>
        </div>

        <label style="display:flex;align-items:center;gap:10px;cursor:pointer;">
          <input type="checkbox"
                 ${checkedAttr}
                 data-entry-id="${entryId}"
                 data-action="change->widget-grid#toggleComplete"
                 style="width:18px;height:18px;flex-shrink:0;cursor:pointer;
                        accent-color:var(--studs-accent,#6366f1);">
          <span style="font-size:14px;font-weight:500;color:#e4e4e7;">
            Mark as complete
          </span>
        </label>

        <div class="completed-at-label"
             data-entry-id="${entryId}"
             style="font-size:11px;color:#71717a;margin-top:8px;margin-left:28px;">
          ${completedText}
        </div>
      </div>`
  }

  // ── Layout persistence ────────────────────────────────────────────────────

  saveLayout() {
    const chartItems       = []
    const trackingPositions = {}

    this.grid.getGridItems().forEach(el => {
      const widgetType = el.dataset.widgetType || ""
      const entryId    = el.dataset.entryId

      if (widgetType === "tracking-card" && entryId) {
        trackingPositions[entryId] = {
          x:         parseInt(el.getAttribute("gs-x") || 0),
          y:         parseInt(el.getAttribute("gs-y") || 0),
          w:         parseInt(el.getAttribute("gs-w") || 4),
          h:         parseInt(el.getAttribute("gs-h") || 3),
          goalHours: el.dataset.goalHours ? parseFloat(el.dataset.goalHours) : null,
        }
      } else {
        chartItems.push({
          x:          parseInt(el.getAttribute("gs-x") || 0),
          y:          parseInt(el.getAttribute("gs-y") || 0),
          w:          parseInt(el.getAttribute("gs-w") || 4),
          h:          parseInt(el.getAttribute("gs-h") || 3),
          widgetType,
          label:      el.dataset.widgetLabel || "",
        })
      }
    })

    localStorage.setItem("widget-layout",          JSON.stringify(chartItems))
    localStorage.setItem("widget-layout-version",  "2")
    localStorage.setItem("tracking-positions",      JSON.stringify(trackingPositions))
  }

  restoreLayout() {
    if (localStorage.getItem("widget-layout-version") !== "2") {
      localStorage.removeItem("widget-layout")
      localStorage.setItem("widget-layout-version", "2")
      return
    }
    const saved = localStorage.getItem("widget-layout")
    if (!saved) return
    try {
      const items = JSON.parse(saved)
      items
        .filter(config => config.widgetType !== "tracking-card")
        .forEach(config => {
          const item = document.createElement("div")
          item.className = "grid-stack-item"
          item.setAttribute("gs-x", config.x)
          item.setAttribute("gs-y", config.y)
          item.setAttribute("gs-w", config.w)
          item.setAttribute("gs-h", config.h)
          item.dataset.widgetType  = config.widgetType
          item.dataset.widgetLabel = config.label

          const inner = document.createElement("div")
          inner.className = "grid-stack-item-content"
          inner.innerHTML = this.renderWidgetBody(config)

          item.appendChild(inner)
          this.gridTarget.appendChild(item)
          this.grid.makeWidget(item)
        })
    } catch (e) {
      console.error("[widget-grid] Failed to restore layout:", e)
    }
  }

  _trackingPositions() {
    try {
      return JSON.parse(localStorage.getItem("tracking-positions") || "{}")
    } catch {
      return {}
    }
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content ?? ""
}

function esc(str) {
  return String(str)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

function heatmapRects() {
  const ops = [0.06, 0.25, 0.45, 0.65, 0.9]
  let s = 42, rects = ""
  for (let w = 0; w < 52; w++) {
    for (let d = 0; d < 5; d++) {
      s = (s * 16807) % 2147483647
      const r = s / 2147483647
      const v = r > 0.85 ? 4 : r > 0.70 ? 3 : r > 0.50 ? 2 : r > 0.30 ? 1 : 0
      rects += `<rect x="${w * 5}" y="${d * 11}" width="4" height="9" rx="1"
                      fill="var(--studs-accent,#6366f1)" opacity="${ops[v]}"/>`
    }
  }
  return rects
}
