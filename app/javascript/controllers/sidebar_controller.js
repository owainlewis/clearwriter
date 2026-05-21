import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "cw:sidebar-collapsed"

// Toggles the .app-shell--collapsed class so CSS can hide the sidebar
// and reclaim the grid column. Remembers the choice in localStorage so
// the layout survives navigation and reloads.
export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.shell = document.querySelector(".app-shell")
    if (!this.shell) return

    // Inline boot script in <head> may have added a one-shot class on <html>
    // to avoid a flash; promote it to a real class on .app-shell and clean up.
    if (document.documentElement.classList.contains("app-shell-collapsed-boot")) {
      this.shell.classList.add("app-shell--collapsed")
      document.documentElement.classList.remove("app-shell-collapsed-boot")
    } else if (this.readPersisted()) {
      this.shell.classList.add("app-shell--collapsed")
    }
    this.syncToggleLabel()
  }

  toggle(event) {
    event.preventDefault()
    if (!this.shell) return

    const collapsed = this.shell.classList.toggle("app-shell--collapsed")
    this.writePersisted(collapsed)
    this.syncToggleLabel()
  }

  syncToggleLabel() {
    if (!this.hasToggleTarget || !this.shell) return
    const collapsed = this.shell.classList.contains("app-shell--collapsed")
    this.toggleTarget.setAttribute("aria-expanded", collapsed ? "false" : "true")
    this.toggleTarget.setAttribute("title", collapsed ? "Show sidebar" : "Hide sidebar")
  }

  readPersisted() {
    try {
      return localStorage.getItem(STORAGE_KEY) === "1"
    } catch {
      return false
    }
  }

  writePersisted(collapsed) {
    try {
      localStorage.setItem(STORAGE_KEY, collapsed ? "1" : "0")
    } catch {
      // ignore — Safari private mode, etc.
    }
  }
}
