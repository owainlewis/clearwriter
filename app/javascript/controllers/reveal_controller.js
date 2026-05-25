import { Controller } from "@hotwired/stimulus"

// Toggles an inline form panel into view and focuses its first field.
// Used by "New collection" / "Rename" / "Add document" so the page stays
// tidy until the user actually wants the form. Works progressively: with
// JS off, mark the panel visible and the trigger hidden via the markup.
export default class extends Controller {
  static targets = ["panel", "trigger", "field"]

  toggle(event) {
    if (event) event.preventDefault()
    const hidden = this.panelTarget.classList.toggle("cw-hidden")
    if (this.hasTriggerTarget) this.triggerTarget.classList.toggle("cw-hidden", !hidden)
    if (!hidden && this.hasFieldTarget) {
      this.fieldTarget.focus()
      this.fieldTarget.select?.()
    }
  }

  // Esc closes the panel and restores the trigger.
  close(event) {
    if (event && event.key !== "Escape") return
    this.panelTarget.classList.add("cw-hidden")
    if (this.hasTriggerTarget) this.triggerTarget.classList.remove("cw-hidden")
  }
}
