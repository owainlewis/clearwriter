import { Controller } from "@hotwired/stimulus"

// A search-as-you-type picker. Debounced fetch of a server-rendered results
// fragment, keyboard navigable, links on click/Enter via the result's own
// Turbo form (which streams the change back). Scales to any number of items
// because it's search-driven, not a giant <select>.
export default class extends Controller {
  static targets = ["input", "menu"]
  static values = { url: String }

  connect() {
    this.index = -1
    this.onOutside = (e) => { if (!this.element.contains(e.target)) this.close() }
    document.addEventListener("click", this.onOutside)
    // After a result links itself (Turbo form inside the menu), keep the
    // picker open and focused so several can be linked in a row.
    this.onLinked = () => { this.inputTarget.focus(); this.refresh() }
    this.element.addEventListener("turbo:submit-end", this.onLinked)
  }

  disconnect() {
    document.removeEventListener("click", this.onOutside)
    this.element.removeEventListener("turbo:submit-end", this.onLinked)
    clearTimeout(this.timer)
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.refresh(), 130)
  }

  async refresh() {
    const res = await fetch(`${this.urlValue}?q=${encodeURIComponent(this.inputTarget.value)}`, {
      headers: { Accept: "text/html" }
    })
    this.menuTarget.innerHTML = await res.text()
    this.menuTarget.hidden = false
    this.index = -1
    this.paint()
  }

  open() { this.refresh() }
  close() { this.menuTarget.hidden = true; this.index = -1 }

  get options() { return Array.from(this.menuTarget.querySelectorAll("[data-option]")) }

  keydown(event) {
    switch (event.key) {
      case "ArrowDown": event.preventDefault(); this.move(1); break
      case "ArrowUp":   event.preventDefault(); this.move(-1); break
      case "Enter": {
        const opt = this.options[this.index] || this.options[0]
        if (opt) { event.preventDefault(); opt.querySelector("button")?.click() }
        break
      }
      case "Escape": this.close(); break
    }
  }

  move(delta) {
    const n = this.options.length
    if (!n) return
    this.index = (this.index + delta + n) % n
    this.paint()
  }

  paint() {
    this.options.forEach((o, i) => o.classList.toggle("picker__option--active", i === this.index))
    this.options[this.index]?.scrollIntoView({ block: "nearest" })
  }
}
