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
    search: %(<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>),
    list: %(<path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M3 6h.01"/><path d="M3 12h.01"/><path d="M3 18h.01"/>),
    grid: %(<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>),
    eye: %(<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/>),
    trash: %(<path d="M3 6h18"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/>),
    copy: %(<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>),
    check: %(<path d="M20 6 9 17l-5-5"/>),
    pin: %(<path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>)
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

  def document_card_excerpt(document)
    text = strip_tags(PairMarkdown.render(document.body.to_s)).squish
    title = document.title.to_s.squish
    text = text.delete_prefix(title).squish if title.present?
    text.presence || "No body yet."
  end
end
