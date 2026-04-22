import { Controller } from "@hotwired/stimulus"
import GridStack from "gridstack/dist/gridstack-all.js"

export default class extends Controller {
  static targets = ["grid"]

  connect() {
    this.grid = GridStack.init(
      { cellHeight: 80, minRow: 4, animate: true },
      this.gridTarget
    )

    this.boundAddWidget = this.addWidget.bind(this)
    window.addEventListener("widget:add", this.boundAddWidget)

    this.restoreLayout()
  }

  disconnect() {
    window.removeEventListener("widget:add", this.boundAddWidget)
    if (this.grid) this.grid.destroy(false)
  }

  addWidget(event) {
    const config = event.detail
    console.log("[widget-grid] addWidget received:", config)

    // Build the element manually — GridStack's `content` option uses textContent
    // in some versions, which would display raw HTML as text.
    const item = document.createElement("div")
    item.className = "grid-stack-item"
    item.setAttribute("gs-w", config.w || 4)
    item.setAttribute("gs-h", config.h || 3)
    item.dataset.widgetType  = config.widgetType || ""
    item.dataset.widgetLabel = config.label || ""

    const inner = document.createElement("div")
    inner.className = "grid-stack-item-content"
    inner.innerHTML = this.renderWidgetBody(config)

    item.appendChild(inner)
    this.gridTarget.appendChild(item)
    this.grid.makeWidget(item)
    this.saveLayout()
  }

  removeWidget(event) {
    const item = event.target.closest(".grid-stack-item")
    if (item) {
      this.grid.removeWidget(item)
      this.saveLayout()
    }
  }

  // Returns the full card HTML that fills .grid-stack-item-content.
  // Uses a flex column so the body stretches as the cell is resized.
  renderWidgetBody(config) {
    const d   = config.serverData || config
    const title = esc(config.label || config.widgetType || "Widget")

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
        <!-- body — flex:1 makes this fill remaining height on resize -->
        <div style="flex:1;min-height:0;padding:10px;overflow:hidden;">
          ${this._widgetContent(config.widgetType, d)}
        </div>
      </div>`
  }

  _widgetContent(type, d) {
    switch (type) {
      case "stat": {
        const val      = d.value != null ? String(d.value) : "—"
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

  saveLayout() {
    const items = []
    this.grid.getGridItems().forEach(el => {
      items.push({
        x:          parseInt(el.getAttribute("gs-x") || 0),
        y:          parseInt(el.getAttribute("gs-y") || 0),
        w:          parseInt(el.getAttribute("gs-w") || 4),
        h:          parseInt(el.getAttribute("gs-h") || 3),
        widgetType: el.dataset.widgetType  || "",
        label:      el.dataset.widgetLabel || "",
      })
    })
    localStorage.setItem("widget-layout", JSON.stringify(items))
    localStorage.setItem("widget-layout-version", "2")
  }

  restoreLayout() {
    // v2 stores {widgetType, label, x, y, w, h} — clear any v1 saves that stored raw innerHTML
    if (localStorage.getItem("widget-layout-version") !== "2") {
      localStorage.removeItem("widget-layout")
      localStorage.setItem("widget-layout-version", "2")
      return
    }
    const saved = localStorage.getItem("widget-layout")
    if (!saved) return
    try {
      const items = JSON.parse(saved)
      items.forEach(config => {
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
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
