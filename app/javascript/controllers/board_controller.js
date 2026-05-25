import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Trello-style drag between the fixed status columns. On drop, it persists the
// new order of whichever column(s) changed by POSTing the ordered task tokens
// to /tasks/reorder. Server is authoritative; we don't re-render optimistically.
export default class extends Controller {
  static targets = ["list"]

  connect() {
    this.sortables = this.listTargets.map((list) =>
      Sortable.create(list, {
        group: "tasks",
        animation: 140,
        easing: "cubic-bezier(0.2, 0, 0, 1)",
        // Mouse-driven fallback instead of native HTML5 drag: consistent
        // ghost styling, touch support, and predictable cross-browser behavior.
        forceFallback: true,
        fallbackTolerance: 4,
        ghostClass: "board__card--ghost",
        chosenClass: "board__card--chosen",
        dragClass: "board__card--drag",
        onEnd: (evt) => {
          this.persist(evt.to)
          if (evt.from !== evt.to) this.persist(evt.from)
        }
      })
    )
  }

  disconnect() {
    this.sortables?.forEach((s) => s.destroy())
    this.sortables = null
  }

  persist(list) {
    const status = list.dataset.status
    const ids = Array.from(list.querySelectorAll("[data-task-id]")).map((el) => el.dataset.taskId)
    fetch("/tasks/reorder", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken,
        Accept: "application/json"
      },
      body: JSON.stringify({ status, ids })
    })
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
