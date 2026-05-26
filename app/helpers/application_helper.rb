module ApplicationHelper
  # Inline stroke icons (Lucide-style, 24-viewbox, currentColor). Kept small
  # and dependency-free so they inherit text colour and size via CSS.
  ICON_PATHS = {
    document: %(<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M8 13h8"/><path d="M8 17h8"/>),
    collection: %(<path d="M4 7a2 2 0 0 1 2-2h3l2 2h7a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/>),
    tag: %(<path d="M12 2H7a2 2 0 0 0-2 2v5l9.29 9.29a2 2 0 0 0 2.83 0l4.17-4.17a2 2 0 0 0 0-2.83z"/><circle cx="9" cy="7" r="1"/>),
    board: %(<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 3v18"/><path d="M15 3v18"/>),
    comment: %(<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8z"/>),
    plus: %(<path d="M12 5v14"/><path d="M5 12h14"/>),
    close: %(<path d="M18 6 6 18"/><path d="M6 6l12 12"/>),
    search: %(<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>)
  }.freeze

  def icon(name, **options)
    paths = ICON_PATHS.fetch(name.to_sym)
    options[:class] = [ "cw-icon", options[:class] ].compact.join(" ")
    content_tag(:svg, raw(paths),
      options.merge(
        viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
        "stroke-width": "1.6", "stroke-linecap": "round", "stroke-linejoin": "round",
        "aria-hidden": "true"
      ))
  end
end
