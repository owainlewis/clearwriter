import { Controller } from "@hotwired/stimulus"
import { EditorView, keymap, drawSelection, ViewPlugin, Decoration } from "@codemirror/view"
import { EditorState } from "@codemirror/state"
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands"
import { markdown } from "@codemirror/lang-markdown"
import { syntaxHighlighting, defaultHighlightStyle, HighlightStyle, syntaxTree } from "@codemirror/language"
import { tags } from "@lezer/highlight"

// Hanging-indent for markdown headings.
//
// All body lines get a small left padding so the `#` symbols on heading
// lines visually overhang into the margin — classic iA-Writer typography
// trick that makes heading structure obvious while editing.
//
// We scan the syntax tree for visible ATXHeading1..6 nodes and tag those
// lines with `cm-heading-line`; CSS does the rest (see writerTheme below).
const headingLineDeco = Decoration.line({ class: "cm-heading-line" })

const hangingHeadingsPlugin = ViewPlugin.fromClass(
  class {
    constructor(view) { this.decorations = this.compute(view) }
    update(update) {
      if (update.docChanged || update.viewportChanged) {
        this.decorations = this.compute(update.view)
      }
    }
    compute(view) {
      const ranges = []
      for (const { from, to } of view.visibleRanges) {
        syntaxTree(view.state).iterate({
          from, to,
          enter: (node) => {
            if (/^ATXHeading[1-6]$/.test(node.name)) {
              const line = view.state.doc.lineAt(node.from)
              ranges.push(headingLineDeco.range(line.from))
            }
          }
        })
      }
      return Decoration.set(ranges, true)
    }
  },
  { decorations: v => v.decorations }
)

const writerHighlight = HighlightStyle.define([
  { tag: tags.heading1, fontWeight: "700", fontSize: "1.6em", lineHeight: "1.3" },
  { tag: tags.heading2, fontWeight: "700", fontSize: "1.35em" },
  { tag: tags.heading3, fontWeight: "700", fontSize: "1.15em" },
  { tag: tags.heading4, fontWeight: "700" },
  { tag: tags.strong, fontWeight: "700" },
  { tag: tags.emphasis, fontStyle: "italic" },
  { tag: tags.link, color: "#1d4ed8", textDecoration: "underline" },
  { tag: tags.url, color: "#6b7280" },
  { tag: tags.monospace, fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace", color: "#374151" },
  { tag: tags.quote, color: "#4b5563", fontStyle: "italic" },
  { tag: tags.list, color: "#374151" },
  { tag: tags.meta, color: "#9ca3af" }
])

const writerTheme = EditorView.theme({
  "&": {
    fontSize: "17px",
    fontFamily: "var(--cw-font-prose)",
    color: "var(--cw-ink)",
    backgroundColor: "transparent"
  },
  ".cm-content": {
    padding: "0",
    lineHeight: "1.7",
    caretColor: "var(--cw-link)"
  },
  ".cm-scroller": { overflow: "auto" },
  ".cm-focused": { outline: "none" },
  // Body lines indent right; heading lines reset to 0 so the `#` overhangs.
  ".cm-line": { paddingLeft: "1.4em" },
  ".cm-heading-line": { paddingLeft: "0" }
})

const SAVE_DEBOUNCE_MS = 800
const MAX_BACKOFF_MS = 60_000

export default class extends Controller {
  static targets = ["textarea", "tags", "status", "fallbackSave", "editorPane", "previewPane"]
  static values = { url: String, previewUrl: String }

  connect() {
    this.backoff = 0
    this.savingCount = 0
    this.previewing = false

    const textarea = this.textareaTarget
    textarea.style.display = "none"

    if (this.hasFallbackSaveTarget) {
      this.fallbackSaveTarget.style.display = "none"
    }

    this.boundKeydown = this.onKeydown.bind(this)
    window.addEventListener("keydown", this.boundKeydown)

    const startState = EditorState.create({
      doc: textarea.value,
      extensions: [
        history(),
        drawSelection(),
        EditorView.lineWrapping,
        markdown(),
        hangingHeadingsPlugin,
        syntaxHighlighting(writerHighlight),
        syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
        writerTheme,
        keymap.of([...defaultKeymap, ...historyKeymap]),
        EditorView.updateListener.of((update) => {
          if (update.docChanged) {
            textarea.value = update.state.doc.toString()
            this.scheduleSave()
          }
        })
      ]
    })

    // Mount CodeMirror inside editorPane so the preview toggle can hide
    // both the textarea and the editor by toggling a single ancestor.
    this.view = new EditorView({
      state: startState,
      parent: this.hasEditorPaneTarget ? this.editorPaneTarget : this.element
    })

    if (this.hasTagsTarget) {
      this.tagsTarget.addEventListener("input", () => this.scheduleSave())
    }
  }

  disconnect() {
    if (this.view) {
      this.view.destroy()
      this.view = null
    }
    if (this.hasTextareaTarget) {
      this.textareaTarget.style.display = ""
    }
    if (this.saveTimer) {
      clearTimeout(this.saveTimer)
      this.saveTimer = null
    }
    if (this.boundKeydown) {
      window.removeEventListener("keydown", this.boundKeydown)
      this.boundKeydown = null
    }
  }

  onKeydown(event) {
    // ⌘R or ⌘⇧P → toggle preview. Don't shadow browser refresh when in a form field with no editor.
    const isCmdR = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "r"
    const isCmdShiftP = (event.metaKey || event.ctrlKey) && event.shiftKey && event.key.toLowerCase() === "p"
    if (!(isCmdR || isCmdShiftP)) return

    event.preventDefault()
    this.togglePreview()
  }

  async togglePreview() {
    if (!this.hasPreviewPaneTarget || !this.hasEditorPaneTarget) return

    if (this.previewing) {
      this.previewPaneTarget.classList.add("hidden")
      this.editorPaneTarget.classList.remove("hidden")
      this.previewing = false
      if (this.view) this.view.focus()
      return
    }

    if (!this.previewUrlValue) return

    try {
      const body = new URLSearchParams()
      body.set("body", this.textareaTarget.value)

      const response = await fetch(this.previewUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "text/html"
        },
        credentials: "same-origin",
        body
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const html = await response.text()
      this.previewPaneTarget.innerHTML = html
      this.editorPaneTarget.classList.add("hidden")
      this.previewPaneTarget.classList.remove("hidden")
      this.previewing = true
    } catch (err) {
      this.setStatus("Couldn't render preview")
    }
  }

  scheduleSave() {
    if (this.saveTimer) clearTimeout(this.saveTimer)
    this.saveTimer = setTimeout(() => this.save(), SAVE_DEBOUNCE_MS)
  }

  async save() {
    if (!this.urlValue) return

    this.savingCount += 1
    this.setStatus("saving", "Saving…")

    const body = new URLSearchParams()
    body.set("document[body]", this.textareaTarget.value)
    if (this.hasTagsTarget) {
      body.set("document[tags_text]", this.tagsTarget.value)
    }

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "text/vnd.turbo-stream.html, text/html"
        },
        credentials: "same-origin",
        body
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      this.savingCount -= 1
      this.backoff = 0
      if (this.savingCount === 0) {
        const now = new Date()
        const time = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
        this.setStatus("saved", `Saved at ${time}`)
      }
    } catch (err) {
      this.savingCount -= 1
      this.backoff = this.backoff === 0 ? 2_000 : Math.min(this.backoff * 2, MAX_BACKOFF_MS)
      this.setStatus("error", `Couldn't save — retrying in ${Math.round(this.backoff / 1000)}s`)
      setTimeout(() => this.save(), this.backoff)
    }
  }

  setStatus(state, label) {
    if (!this.hasStatusTarget) return
    this.statusTarget.dataset.state = state
    this.statusTarget.setAttribute("title", label)
  }

  updateWordCount(text) {
    if (!this.hasWordCountTarget) return
    const words = text.trim() ? text.trim().split(/\s+/).length : 0
    this.wordCountTarget.textContent = `${words.toLocaleString()} word${words === 1 ? "" : "s"}`
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
