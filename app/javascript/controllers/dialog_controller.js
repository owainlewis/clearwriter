import { Controller } from "@hotwired/stimulus"

// Opens a native <dialog> as a modal: backdrop, focus trap, and Esc-to-close
// come for free from the platform. The trigger button and the <dialog> both
// live inside this controller's element. Used for "New collection" and similar
// create/edit forms so they feel like a modern modal rather than an inline
// web form.
export default class extends Controller {
  static targets = ["dialog", "field"]

  open(event) {
    if (event) event.preventDefault()
    this.dialogTarget.showModal()
    // Focus the first field after the dialog paints.
    if (this.hasFieldTarget) requestAnimationFrame(() => this.fieldTarget.focus())
  }

  close(event) {
    if (event) event.preventDefault()
    this.dialogTarget.close()
  }

  // Clicking the backdrop (the <dialog> itself, outside the inner panel) closes.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }
}
