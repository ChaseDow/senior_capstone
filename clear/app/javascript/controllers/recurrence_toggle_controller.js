import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["toggle", "details"];

  connect() {
    this.sync();
  }

  sync() {
    const checked = this.toggleTarget.checked;

    this.detailsTarget.classList.toggle("hidden", !checked);

    this.detailsTarget.querySelectorAll("input, select, textarea").forEach((el) => {
      el.disabled = !checked;
    });
  }

  toggle() {
    this.sync();
  }
}
