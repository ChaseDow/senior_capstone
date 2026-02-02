import "@hotwired/turbo-rails"
import "./controllers"

const applyMode = (mode) => {
  document.documentElement.dataset.mode = mode
  if (document.body) document.body.dataset.mode = mode
  try { localStorage.setItem("mode", mode) } catch (e) {}
}

const applySavedMode = () => {
  let mode = "black"
  try { mode = localStorage.getItem("mode") || "black" } catch (e) {}
  applyMode(mode)
}

applySavedMode()

document.addEventListener("turbo:load", () => {
  applySavedMode()
})

if (!window.__modeButtonsBound) {
  window.__modeButtonsBound = true

  document.addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-set-mode]")
    if (!btn) return
    const mode = btn.getAttribute("data-set-mode")
    if (!mode) return
    applyMode(mode)
  })
}

// Mode switching + readout (Turbo-safe)
(() => {
  if (window.__clearModeBound) return;
  window.__clearModeBound = true;

  const html = document.documentElement;

  const setMode = (mode) => {
    if (!mode) return;
    html.dataset.mode = mode;
    try { localStorage.setItem("mode", mode); } catch (e) {}
  };

  const updateReadouts = () => {
    const mode = html.dataset.mode || "(none)";
    document.querySelectorAll("[data-mode-readout]").forEach((el) => {
      el.textContent = mode;
    });
  };

  // Click handler for any button with data-set-mode
  document.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-set-mode]");
    if (!btn) return;
    setMode(btn.dataset.setMode);
    updateReadouts();
  });

  // Keep readout correct after Turbo navigation/frame renders
  document.addEventListener("turbo:load", updateReadouts);
  document.addEventListener("turbo:render", updateReadouts);

  // If something else changes data-mode, keep readout in sync
  const obs = new MutationObserver(updateReadouts);
  obs.observe(html, { attributes: true, attributeFilter: ["data-mode"] });

  // Initial
  updateReadouts();
})();
