import { Controller } from "@hotwired/stimulus"

const COPIED_RESET_MS = 1000

export default class extends Controller {
  static targets = ["source"]
  static values = { url: String }

  async copy(event) {
    event.preventDefault()

    const button = event.currentTarget
    const originalLabel = button.dataset.copyMarkdownOriginalLabel || button.textContent.trim()
    button.dataset.copyMarkdownOriginalLabel = originalLabel

    try {
      await navigator.clipboard.writeText(await this.markdown())
      this.setTemporaryLabel(button, "Copied")
    } catch (err) {
      this.setTemporaryLabel(button, "Couldn't copy")
    }
  }

  async markdown() {
    if (this.hasSourceTarget) return this.sourceTarget.value

    if (this.hasUrlValue) {
      const response = await fetch(this.urlValue, {
        headers: { "Accept": "text/markdown, text/plain" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      return response.text()
    }

    return ""
  }

  setTemporaryLabel(button, label) {
    const originalLabel = button.dataset.copyMarkdownOriginalLabel

    if (button.copyMarkdownTimer) clearTimeout(button.copyMarkdownTimer)
    button.textContent = label
    button.copyMarkdownTimer = setTimeout(() => {
      button.textContent = originalLabel
      button.copyMarkdownTimer = null
    }, COPIED_RESET_MS)
  }
}
