import { Controller } from "@hotwired/stimulus"
import GridStack from "gridstack/dist/gridstack-all.js"

// Default dimensions for each widget type (used when DB has no stored size yet)
const WIDGET_META = {
  stat:     { title: "Stat Card",        defaultW: 2, defaultH: 2 },
  progress: { title: "Progress",         defaultW: 3, defaultH: 2 },
  line:     { title: "Line Chart",       defaultW: 4, defaultH: 3 },
  bar:      { title: "Bar Chart",        defaultW: 4, defaultH: 3 },
  pie:      { title: "Donut Chart",      defaultW: 3, defaultH: 3 },
  area:     { title: "Area Chart",       defaultW: 4, defaultH: 3 },
  heatmap:  { title: "Activity Heatmap", defaultW: 6, defaultH: 3 },
}

export default class extends Controller {
  static targets = ["canvas", "emptyHint"]

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  connect() {
    console.log("[widget-dashboard] connect()")
    this._gridReady = false

    // Defer GridStack init until the Personal tab is first shown (visible).
    // Initializing on a hidden element (display:none) gives 0px column width,
    // making every widget invisible.
    this._onTabActivated = (e) => {
      if (e.detail?.tab !== "person") return
      if (!this._gridReady) {
        this._initGrid()
      } else if (this.grid) {
        // Already initialized — just force a layout recalculation.
        requestAnimationFrame(() => window.dispatchEvent(new Event("resize")))
      }
    }
    window.addEventListener("analytics:tab-activated", this._onTabActivated)

    // Receive widget data from the drawer (both configured and mock widgets).
    // Buffer incoming widgets if the grid isn't ready yet.
    this._pendingWidgets = []
    this._onDrawerSelect = (e) => {
      console.log("[widget-dashboard] analytics:widget-added received, data:", e.detail?.widgetData)
      const data = e.detail?.widgetData
      if (!data) return
      if (this._gridReady) {
        this.renderWidget(data)
      } else {
        this._pendingWidgets.push(data)
      }
    }
    window.addEventListener("analytics:widget-added", this._onDrawerSelect)

    // If the Personal tab is already active when this controller connects
    // (e.g. user refreshed while on Personal), init immediately.
    const activeTab = localStorage.getItem("analytics:active-tab") || "overview"
    if (activeTab === "person") {
      this._initGrid()
    }
  }

  _initGrid() {
    if (this._gridReady) return
    console.log("[widget-dashboard] _initGrid() — element visible, initializing GridStack")

    this.grid = GridStack.init(
      {
        cellHeight: 80,
        column: 12,
        animate: true,
        handle: ".widget-drag-handle",
        resizable: { handles: "se" },
        margin: 8,
        columnOpts: { breakpoints: [{ w: 640, c: 1 }] },
      },
      this.canvasTarget
    )

    // Debounced position save on drag / resize
    this.grid.on("change", () => {
      clearTimeout(this._saveTimer)
      this._saveTimer = setTimeout(() => this.savePositions(), 800)
    })

    this._gridReady = true
    console.log("[widget-dashboard] grid initialized:", !!this.grid)

    this.loadFromServer()
  }

  disconnect() {
    clearTimeout(this._saveTimer)
    window.removeEventListener("analytics:tab-activated", this._onTabActivated)
    window.removeEventListener("analytics:widget-added", this._onDrawerSelect)

    if (this.grid) {
      this.grid.destroy(false)
      this.grid = null
    }
    this._gridReady = false
    this._pendingWidgets = []
    this.canvasTarget.innerHTML = ""
  }

  // ── Server load ───────────────────────────────────────────────────────────

  async loadFromServer() {
    try {
      const res = await fetch("/analytics/widgets.json", {
        headers: { Accept: "application/json" },
      })
      if (!res.ok) return
      const widgets = await res.json()
      widgets.forEach((w) => this.renderWidget(w))
    } catch (e) {
      console.error("Failed to load widgets:", e)
    } finally {
      this.updateEmptyState()
    }
  }

  // ── Render a single widget from server JSON ───────────────────────────────

  renderWidget(data) {
    console.log("[widget-dashboard] renderWidget, grid:", !!this.grid, "data:", data)
    const meta  = WIDGET_META[data.type] ?? { title: data.title || data.type, defaultW: data.w || 2, defaultH: data.h || 2 }
    const w     = data.w ?? meta.defaultW
    const h     = data.h ?? meta.defaultH
    const title = data.title || meta.title

    // Build the full .grid-stack-item element ourselves so we control the structure
    const el = document.createElement("div")
    el.className = "grid-stack-item"
    el.dataset.widgetConfigId = String(data.id)
    el.dataset.widgetType     = data.type
    el.setAttribute("gs-w", w)
    el.setAttribute("gs-h", h)
    if (data.x != null) el.setAttribute("gs-x", data.x)
    if (data.y != null) el.setAttribute("gs-y", data.y)

    el.innerHTML = `<div class="grid-stack-item-content">${buildWidgetHTML(data.id, data.type, title, data)}</div>`

    this.canvasTarget.appendChild(el)
    const result = this.grid.makeWidget(el)
    console.log("[widget-dashboard] makeWidget result:", result, "nodes:", this.grid.engine.nodes.length)
    this.updateEmptyState()
  }

  // ── Remove widget ─────────────────────────────────────────────────────────

  async removeWidget(event) {
    const configId = event.currentTarget.dataset.configId
    if (!configId) return

    const el = this.canvasTarget.querySelector(`[data-widget-config-id="${configId}"]`)
    if (el && this.grid) {
      this.grid.removeWidget(el, true)
      this.updateEmptyState()

      try {
        await fetch(`/widget_configs/${configId}`, {
          method:  "DELETE",
          headers: { "X-CSRF-Token": csrfToken() },
        })
      } catch (e) {
        console.error("Failed to delete widget:", e)
      }
    }
  }

  // ── Position persistence ──────────────────────────────────────────────────

  savePositions() {
    if (!this.grid) return
    const token = csrfToken()
    this.grid.engine.nodes.forEach((node) => {
      const configId = node.el?.dataset.widgetConfigId
      if (!configId) return
      fetch(`/widget_configs/${configId}`, {
        method:  "PATCH",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body:    JSON.stringify({
          widget_config: { gs_x: node.x, gs_y: node.y, gs_w: node.w, gs_h: node.h },
        }),
      }).catch((e) => console.error("Failed to save position:", e))
    })
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  updateEmptyState() {
    if (!this.hasEmptyHintTarget) return
    const hasWidgets = (this.grid?.engine?.nodes?.length ?? 0) > 0
    this.emptyHintTarget.style.display = hasWidgets ? "none" : ""
  }
}

// ─── DOM builder ─────────────────────────────────────────────────────────────

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content ?? ""
}

function esc(str) {
  return String(str)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

// Returns the inner HTML placed inside .grid-stack-item-content
function buildWidgetHTML(configId, type, title, data) {
  return `
    <div class="widget-card">
      <div class="widget-drag-handle">
        <span class="widget-title">${esc(title)}</span>
        <button class="widget-remove-btn"
                data-action="click->widget-dashboard#removeWidget"
                data-config-id="${esc(String(configId))}"
                aria-label="Remove widget">×</button>
      </div>
      <div class="widget-body">${buildWidgetContent(type, data)}</div>
    </div>`
}

function buildWidgetContent(type, data = {}) {
  switch (type) {
    case "stat":     return statCard(data)
    case "progress": return progressWidget(data)
    case "line":     return lineChart()
    case "bar":      return barChart()
    case "pie":      return pieChart()
    case "area":     return areaChart()
    case "heatmap":  return heatmap()
    default:
      return `<p style="color:#71717a;font-size:12px;padding:8px">Unknown type</p>`
  }
}

// ─── Configured widget builders (use real server data) ───────────────────────

function statCard(data = {}) {
  const hasValue = data.value !== null && data.value !== undefined
  const value    = hasValue ? String(data.value) : "—"
  const label    = esc(data.title || "Stat")
  const metricLbl = { count: "items", duration_hours: "hrs" }[data.metric] || ""
  const periodLbl = { week: "this week", month: "this month", all_time: "all time" }[data.period] || ""
  const sub = [metricLbl, periodLbl].filter(Boolean).join(" · ")

  return `
    <div style="display:flex;flex-direction:column;align-items:center;
                justify-content:center;height:100%;text-align:center;gap:8px;padding:8px">
      <p style="font-size:10px;color:#71717a;font-weight:600;
                letter-spacing:0.08em;text-transform:uppercase;
                max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${label}</p>
      <p style="font-size:40px;font-weight:700;color:#f4f4f5;line-height:1">${esc(value)}</p>
      ${sub ? `<p style="font-size:10px;color:#52525b">${esc(sub)}</p>` : ""}
      ${!hasValue && data.source_type
        ? `<p style="font-size:10px;color:#f59e0b">No trackable ${esc(data.source_type.toLowerCase())}s found</p>`
        : ""}
    </div>`
}

function progressWidget(data = {}) {
  const current  = Number(data.current ?? data.value ?? 0)
  const goal     = Number(data.goal ?? 0)
  const pct      = data.pct ?? (goal > 0 ? Math.min(Math.round(current / goal * 100), 100) : 0)
  const color    = pct >= 80 ? "#34d399" : pct >= 50 ? "var(--studs-accent)" : "#f59e0b"
  const note     = pct >= 100 ? "🎉 Goal reached!" : pct >= 80 ? "🎯 Almost there!" : pct >= 50 ? "Keep going!" : "Just started"
  const unitLbl  = { count: "", duration_hours: " hrs" }[data.metric] || ""
  const periodLbl = { week: "/wk", month: "/mo" }[data.period] || ""
  const label    = esc(data.title || "Progress")

  return `
    <div style="display:flex;flex-direction:column;justify-content:center;
                height:100%;gap:10px;padding:0 4px">
      <div style="display:flex;justify-content:space-between;align-items:baseline">
        <span style="font-size:12px;font-weight:600;color:#d4d4d8">${label}</span>
        <span style="font-size:11px;color:#71717a">${current}${unitLbl} / ${goal}${unitLbl}${periodLbl}</span>
      </div>
      <div style="position:relative;height:12px;background:var(--studs-border);
                  border-radius:999px;overflow:hidden">
        <div style="position:absolute;inset-y:0;left:0;width:${pct}%;background:${color};
                    border-radius:999px;
                    animation:widget-progress-fill 0.8s cubic-bezier(0.22,1,0.36,1) forwards">
        </div>
      </div>
      <div style="display:flex;align-items:center;justify-content:space-between">
        <span style="font-size:11px;color:#71717a">${note}</span>
        <span style="font-size:14px;font-weight:700;color:${color}">${pct}%</span>
      </div>
    </div>`
}

// ─── Mock / visual widget builders ───────────────────────────────────────────

function lineChart() {
  const data   = [38, 62, 45, 78, 55, 88, 72]
  const labels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
  const W = 280, H = 110
  const pL = 10, pR = 10, pT = 14, pB = 22

  const pts  = scalePoints(data, W, H, pL, pR, pT, pB)
  const poly = pts.map(p => `${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(" ")
  const dots = pts.map((p, i) => `
    <circle cx="${p.x.toFixed(1)}" cy="${p.y.toFixed(1)}" r="3"
            fill="var(--studs-accent)" stroke="var(--studs-sidebar-bg)" stroke-width="1.5"/>
    <text x="${p.x.toFixed(1)}" y="${(H-pB+13).toFixed(1)}"
          text-anchor="middle" class="chart-lbl">${labels[i]}</text>`).join("")

  return `
    <svg viewBox="0 0 ${W} ${H}" class="w-full h-full" preserveAspectRatio="none">
      ${gridLines(W, H, pL, pR, pT, pB)}
      <polyline points="${poly}" fill="none"
                stroke="var(--studs-accent)" stroke-width="2.5"
                stroke-linecap="round" stroke-linejoin="round"/>
      ${dots}
    </svg>`
}

function areaChart() {
  const data = [20, 45, 35, 60, 50, 75, 65, 80, 70, 90]
  const W = 280, H = 110, pL = 10, pR = 10, pT = 14, pB = 22
  const gradId = `wg-ag-${uid()}`

  const pts      = scalePoints(data, W, H, pL, pR, pT, pB)
  const linePath = pts.map((p,i) => `${i===0?"M":"L"}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(" ")
  const areaPath = `${linePath} L${pts[pts.length-1].x.toFixed(1)},${(H-pB).toFixed(1)} L${pts[0].x.toFixed(1)},${(H-pB).toFixed(1)} Z`

  return `
    <svg viewBox="0 0 ${W} ${H}" class="w-full h-full" preserveAspectRatio="none">
      <defs>
        <linearGradient id="${gradId}" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%"   stop-color="var(--studs-accent)" stop-opacity="0.45"/>
          <stop offset="100%" stop-color="var(--studs-accent)" stop-opacity="0.02"/>
        </linearGradient>
      </defs>
      ${gridLines(W, H, pL, pR, pT, pB)}
      <path d="${areaPath}" fill="url(#${gradId})"/>
      <path d="${linePath}" fill="none"
            stroke="var(--studs-accent)" stroke-width="2.5"
            stroke-linecap="round" stroke-linejoin="round"/>
    </svg>`
}

function barChart() {
  const data = [
    {label:"Mon",value:45},{label:"Tue",value:70},
    {label:"Wed",value:30},{label:"Thu",value:85},
    {label:"Fri",value:60},{label:"Sat",value:22},
  ]
  const W = 280, H = 110, pL = 10, pR = 10, pT = 14, pB = 22
  const cW = W-pL-pR, cH = H-pT-pB
  const slotW = cW/data.length, barW = Math.floor(slotW*0.55)

  const bars = data.map((d,i) => {
    const bh  = (d.value/100)*cH
    const x   = pL + i*slotW + (slotW-barW)/2
    const y   = pT + cH - bh
    return `
      <rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${barW}" height="${bh.toFixed(1)}"
            rx="3" fill="var(--studs-accent)" opacity="${(0.4+(d.value/100)*0.6).toFixed(2)}"/>
      <text x="${(x+barW/2).toFixed(1)}" y="${(H-pB+13).toFixed(1)}"
            text-anchor="middle" class="chart-lbl">${d.label}</text>`
  }).join("")

  return `
    <svg viewBox="0 0 ${W} ${H}" class="w-full h-full" preserveAspectRatio="none">
      ${gridLines(W, H, pL, pR, pT, pB)}${bars}
    </svg>`
}

function pieChart() {
  const segs = [
    {label:"Events",value:40,color:"#60a5fa"},
    {label:"Courses",value:25,color:"#34d399"},
    {label:"Shifts",value:20,color:"#a78bfa"},
    {label:"Tasks",value:15,color:"#fbbf24"},
  ]
  const total = segs.reduce((s,d)=>s+d.value, 0)
  let cum = 0
  const circles = segs.map(seg => {
    const pct = (seg.value/total)*100, off = 100-cum
    cum += pct
    return `<circle cx="21" cy="21" r="15.915" fill="none"
              stroke="${seg.color}" stroke-width="4"
              stroke-dasharray="${pct.toFixed(2)} ${(100-pct).toFixed(2)}"
              stroke-dashoffset="${off.toFixed(2)}" stroke-linecap="butt"/>`
  }).join("")
  const legend = segs.map(s => `
    <div style="display:flex;align-items:center;gap:5px;margin-bottom:3px">
      <span style="width:8px;height:8px;border-radius:50%;background:${s.color};flex-shrink:0"></span>
      <span style="font-size:10px;color:#a1a1aa;flex:1">${s.label}</span>
      <span style="font-size:10px;font-weight:600;color:#e4e4e7">${s.value}%</span>
    </div>`).join("")

  return `
    <div style="display:flex;align-items:center;gap:12px;height:100%;padding:4px">
      <div style="position:relative;flex-shrink:0;width:80px;height:80px">
        <svg viewBox="0 0 42 42" style="width:100%;height:100%;transform:rotate(-90deg)">
          <circle cx="21" cy="21" r="15.915" fill="none" stroke-width="4"
                  style="stroke:var(--studs-border)"/>
          ${circles}
        </svg>
        <div style="position:absolute;inset:0;display:flex;flex-direction:column;
                    align-items:center;justify-content:center;pointer-events:none">
          <span style="font-size:18px;font-weight:700;color:#f4f4f5">${total}</span>
          <span style="font-size:9px;color:#a1a1aa">total</span>
        </div>
      </div>
      <div style="flex:1;min-width:0">${legend}</div>
    </div>`
}

function heatmap() {
  const WEEKS=52, DAYS=7, CELL=9, GAP=2, PAD_L=26, PAD_T=18
  const W = PAD_L + WEEKS*(CELL+GAP), H = PAD_T + DAYS*(CELL+GAP)
  const ops = [0.06, 0.25, 0.45, 0.65, 0.9]
  const rng = seededRng(42)
  const rects = []
  for (let w=0;w<WEEKS;w++) for (let d=0;d<DAYS;d++) {
    const v = weightedVal(rng)
    rects.push(`<rect x="${PAD_L+w*(CELL+GAP)}" y="${PAD_T+d*(CELL+GAP)}"
                      width="${CELL}" height="${CELL}" rx="2"
                      fill="var(--studs-accent)" opacity="${ops[v]}"/>`)
  }
  const dayNames = ["","Mon","","Wed","","Fri",""]
  const dayLbls  = dayNames.map((n,d) => !n ? "" :
    `<text x="${PAD_L-4}" y="${(PAD_T+d*(CELL+GAP)+CELL*0.85).toFixed(1)}"
           text-anchor="end" class="chart-lbl">${n}</text>`).join("")
  const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
  const moLbls = MONTHS.map((m,i) =>
    `<text x="${PAD_L + Math.floor(i*WEEKS/12)*(CELL+GAP)}" y="${PAD_T-6}" class="chart-lbl">${m}</text>`).join("")

  return `<svg viewBox="0 0 ${W} ${H}" class="w-full h-full"
               preserveAspectRatio="xMinYMid meet" style="overflow:visible">
    ${moLbls}${dayLbls}${rects.join("")}
  </svg>`
}

// ─── SVG helpers ─────────────────────────────────────────────────────────────

function uid() { return Math.random().toString(36).slice(2, 8) }

function scalePoints(data, W, H, pL, pR, pT, pB) {
  const cW = W-pL-pR, cH = H-pT-pB, max = Math.max(...data)*1.08
  return data.map((v,i) => ({
    x: pL + (i/(data.length-1))*cW,
    y: pT + cH - (v/max)*cH,
  }))
}

function gridLines(W, H, pL, pR, pT, pB) {
  const lines = []
  for (let i=1;i<=4;i++) {
    const y = (pT + ((H-pT-pB)*i)/4).toFixed(1)
    lines.push(`<line x1="${pL}" y1="${y}" x2="${W-pR}" y2="${y}"
                      stroke="rgba(255,255,255,0.05)" stroke-width="1"/>`)
  }
  return lines.join("")
}

function seededRng(seed) {
  let s = seed
  return () => { s = (s*16807)%2147483647; return s/2147483647 }
}

function weightedVal(rng) {
  const r = rng()
  return r>0.85?4:r>0.70?3:r>0.50?2:r>0.30?1:0
}
