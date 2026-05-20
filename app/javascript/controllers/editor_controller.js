import { Controller } from "@hotwired/stimulus"
import { EditorView, keymap, drawSelection } from "@codemirror/view"
import { EditorState } from "@codemirror/state"
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands"
import { markdown } from "@codemirror/lang-markdown"
import { syntaxHighlighting, defaultHighlightStyle, HighlightStyle } from "@codemirror/language"
import { tags } from "@lezer/highlight"

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
    fontFamily: "'iA Writer Quattro S', 'iA Writer Duo S', ui-sans-serif, system-ui, -apple-system, sans-serif",
    color: "#111827",
    backgroundColor: "transparent"
  },
  ".cm-content": {
    padding: "12px 0",
    lineHeight: "1.7",
    caretColor: "#1d4ed8"
  },
  ".cm-scroller": { overflow: "auto" },
  ".cm-focused": { outline: "none" },
  ".cm-line": { padding: "0" }
})

export default class extends Controller {
  static targets = ["textarea"]

  connect() {
    const textarea = this.textareaTarget
    textarea.style.display = "none"

    const startState = EditorState.create({
      doc: textarea.value,
      extensions: [
        history(),
        drawSelection(),
        EditorView.lineWrapping,
        markdown(),
        syntaxHighlighting(writerHighlight),
        syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
        writerTheme,
        keymap.of([...defaultKeymap, ...historyKeymap]),
        EditorView.updateListener.of((update) => {
          if (update.docChanged) {
            textarea.value = update.state.doc.toString()
          }
        })
      ]
    })

    this.view = new EditorView({
      state: startState,
      parent: this.element
    })
  }

  disconnect() {
    if (this.view) {
      this.view.destroy()
      this.view = null
    }
    if (this.hasTextareaTarget) {
      this.textareaTarget.style.display = ""
    }
  }
}
