require "commonmarker"

# Single source of truth for markdown → HTML. Used by:
#   - the edit-page preview action
#   - the public share routes (/d/:token) — coming in #9
#   - any future agent-facing rendered surfaces
#
# Safe mode is non-negotiable: no raw HTML pass-through, no javascript: URLs.
module AtriumMarkdown
  OPTIONS = {
    extension: {
      table: true,
      strikethrough: true,
      autolink: true,
      tagfilter: true,
      tasklist: true,
      footnotes: true
    },
    render: {
      unsafe: false,
      hardbreaks: false
    }
  }.freeze

  def self.render(markdown)
    return "" if markdown.blank?

    Commonmarker.to_html(markdown.to_s, options: OPTIONS).html_safe
  end
end
