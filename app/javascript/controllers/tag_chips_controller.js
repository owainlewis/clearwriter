import { Controller } from "@hotwired/stimulus"

// Chip-based tag input.
//
// Renders the current tags as removable pills + a free-text input that
// commits on Enter / comma / blur. The committed list is mirrored into
// a hidden field named "document[tags_text]" so the existing PATCH
// payload (autosave or fallback form submit) keeps working unchanged.
export default class extends Controller {
  static targets = ["list", "input", "hidden"]

  connect() {
    this.tags = this.parseInitial()
    this.render()
  }

  parseInitial() {
    const raw = (this.hasHiddenTarget ? this.hiddenTarget.value : "") || ""
    return this.normalize(raw.split(","))
  }

  normalize(values) {
    const seen = new Set()
    const out = []
    for (const v of values) {
      const t = (v || "").trim().toLowerCase().replace(/^#/, "").replace(/\s+/g, "-")
      if (!t) continue
      if (seen.has(t)) continue
      seen.add(t)
      out.push(t)
    }
    return out
  }

  onKey(event) {
    const value = this.inputTarget.value

    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      this.commit(value)
      this.inputTarget.value = ""
      return
    }

    // Backspace on empty input removes the last chip.
    if (event.key === "Backspace" && value === "" && this.tags.length) {
      event.preventDefault()
      this.tags.pop()
      this.persistAndRender()
      return
    }
  }

  onBlur() {
    if (this.inputTarget.value) {
      this.commit(this.inputTarget.value)
      this.inputTarget.value = ""
    }
  }

  commit(raw) {
    const next = this.normalize([...this.tags, ...raw.split(",")])
    if (next.length === this.tags.length && next.every((t, i) => t === this.tags[i])) return
    this.tags = next
    this.persistAndRender()
  }

  remove(event) {
    const tag = event.params.tag
    this.tags = this.tags.filter(t => t !== tag)
    this.persistAndRender()
    this.inputTarget.focus()
  }

  focusInput() {
    this.inputTarget.focus()
  }

  persistAndRender() {
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = this.tags.join(", ")
      this.hiddenTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
    this.render()
  }

  render() {
    if (!this.hasListTarget) return
    this.listTarget.innerHTML = this.tags.map(tag => this.chipHtml(tag)).join("")
  }

  chipHtml(tag) {
    const safe = this.escape(tag)
    return `
      <li class="cw-chips__chip">
        <span class="cw-chips__chip-label">#${safe}</span>
        <button type="button"
                class="cw-chips__chip-remove"
                data-action="tag-chips#remove"
                data-tag-chips-tag-param="${safe}"
                aria-label="Remove tag ${safe}">×</button>
      </li>`
  }

  escape(s) {
    return String(s).replace(/[&<>"']/g, ch => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[ch]))
  }
}
