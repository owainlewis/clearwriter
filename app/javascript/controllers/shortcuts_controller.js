import { Controller } from "@hotwired/stimulus"

// Global "new resource" keyboard shortcuts. A leading "n" (for "new") arms a
// brief window; the next key picks what to create:
//   n d → new document   n t → new task   n c → new collection
// The two-key chord means a stray keypress never creates anything. Ignored
// while typing in a field or when a modal dialog is open. Each shortcut just
// submits a hidden form, so creation, CSRF, and redirects flow through Rails.
export default class extends Controller {
  static targets = ["document", "task", "collection"]

  connect() {
    this.armed = false
    this.timer = null
    this.handler = this.onKeydown.bind(this)
    window.addEventListener("keydown", this.handler)
  }

  disconnect() {
    window.removeEventListener("keydown", this.handler)
    clearTimeout(this.timer)
  }

  onKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return
    if (this.isTyping(event.target)) return
    if (document.querySelector("dialog[open]")) return

    const key = event.key.toLowerCase()

    if (this.armed) {
      this.disarm()
      let form = null
      if (key === "d" && this.hasDocumentTarget) form = this.documentTarget
      else if (key === "t" && this.hasTaskTarget) form = this.taskTarget
      else if (key === "c" && this.hasCollectionTarget) form = this.collectionTarget
      if (form) {
        event.preventDefault()
        form.requestSubmit()
      }
      return
    }

    if (key === "n") {
      event.preventDefault()
      this.arm()
    }
  }

  arm() {
    this.armed = true
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.disarm(), 1500)
  }

  disarm() {
    this.armed = false
    clearTimeout(this.timer)
  }

  isTyping(el) {
    if (!el) return false
    const tag = el.tagName
    return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || el.isContentEditable
  }
}
