import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["overlay", "panel", "frame", "skeleton"];
  static values = {
    url: String, 
  };

  connect() {
    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close();
    };
    document.addEventListener("keydown", this._onKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown);
  }

  open(e) {
    e?.preventDefault?.();
    const date = e?.params?.date || e?.currentTarget?.dataset?.date || null;
    this.openForDate(date);
  }

    openForDate(date) {
    const url = this.buildUrl(date);

    this.overlayTarget.classList.remove("opacity-0", "pointer-events-none");
    this.overlayTarget.classList.add("opacity-100");

    this.panelTarget.classList.remove("translate-x-[120%]");
    this.panelTarget.classList.add("translate-x-0");

    this.panelTarget.style.width = "360px";

    if (this.frameTarget.src !== url) {
        this.frameTarget.src = url;
    } else {
        this.frameTarget.reload();
    }
    }

    close() {
    this.overlayTarget.classList.add("opacity-0", "pointer-events-none");
    this.overlayTarget.classList.remove("opacity-100");

    this.panelTarget.classList.add("translate-x-[120%]");
    this.panelTarget.classList.remove("translate-x-0");

    window.setTimeout(() => {
        this.panelTarget.style.width = "0px";
    }, 300);
    window.dispatchEvent(new CustomEvent("agenda:clear"))
    }


  showSkeleton() {
    if (!this.hasSkeletonTarget) return;
    this.frameTarget.innerHTML = this.skeletonTarget.innerHTML;
  }

  frameLoaded() {
    this.resizeFromFrame();
  }

  resizeFromFrame() {
    const countEl = this.frameTarget.querySelector("[data-agenda-count]");
    const count = countEl ? parseInt(countEl.dataset.agendaCount, 10) : 0;

    const min = 300;
    const max = 560;
    const width = Math.max(min, Math.min(max, 320 + count * 28));

    this.panelTarget.style.width = `${width}px`;
  }

  buildUrl(date) {
    const u = new URL(this.urlValue, window.location.origin);
    if (date) u.searchParams.set("date", date);
    return u.toString();
  }
}
