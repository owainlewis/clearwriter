require "test_helper"

class AtriumMarkdownTest < ActiveSupport::TestCase
  test "renders headings, emphasis, links" do
    html = AtriumMarkdown.render("# Title\n\n**bold** _italic_ [link](https://x)")
    assert_match %r{<h1[^>]*>.*Title.*</h1>}m, html
    assert_includes html, "<strong>"
    assert_includes html, "<em>"
    assert_includes html, "<a href"
  end

  test "renders GFM task lists with disabled checkboxes" do
    html = AtriumMarkdown.render("- [ ] todo\n- [x] done\n")
    assert_includes html, '<input type="checkbox" disabled="" />'
    assert_includes html, '<input type="checkbox" checked="" disabled="" />'
  end

  test "safe mode strips raw HTML / script tags" do
    html = AtriumMarkdown.render("<script>alert(1)</script>")
    assert_not_includes html, "<script>"
  end

  test "empty body returns empty string" do
    assert_equal "", AtriumMarkdown.render("")
    assert_equal "", AtriumMarkdown.render(nil)
  end

  test "fenced code blocks rendered as <pre><code>" do
    html = AtriumMarkdown.render("```\nputs 1\n```\n")
    assert_includes html, "<pre"
    assert_includes html, "<code"
  end
end
