require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @doc   = @alice.documents.create!(body: "# Alice doc")
  end

  test "signed-out requests redirect to sign in" do
    get documents_path
    assert_redirected_to new_session_path
  end

  test "signed-in user sees their own docs" do
    sign_in_as @alice
    get documents_path
    assert_response :success
    assert_includes response.body, "Alice doc"
  end

  test "documents index does not show other users' docs" do
    @bob.documents.create!(body: "# Bob secret")
    sign_in_as @alice
    get documents_path(since: "all")
    assert_response :success
    assert_not_includes response.body, "Bob secret"
  end

  test "documents index can render grid cards and preserve filters in view toggle" do
    card = @alice.documents.create!(
      body: "# Atomic card\n\nOne idea explained clearly.",
      tags_text: "lesson"
    )

    sign_in_as @alice
    get documents_path(since: "all", tag: "lesson", view: "grid")

    assert_response :success
    assert_select ".cw-doc-grid"
    assert_select "a.cw-doc-card[href=?]", edit_document_path(card) do
      assert_select ".cw-doc-card__title", "Atomic card"
      assert_select ".cw-doc-card__excerpt", /One idea explained clearly/
      assert_select ".cw-chip--tag", "lesson"
    end
    assert_select "a[href=?].cw-view-toggle__item--active",
      documents_path(since: "all", tag: "lesson", view: "grid")
    assert_select "a[href=?]",
      documents_path(since: "all", tag: "lesson", view: "list")
  end

  test "pinned docs sort to the top of the list regardless of recency" do
    # @doc ("Alice doc") is created first, so it's the older of the two.
    newer = @alice.documents.create!(body: "# Newer doc")
    @doc.update!(pinned: true)

    sign_in_as @alice
    get documents_path(since: "all")

    assert_response :success
    pinned_at  = response.body.index("Alice doc")
    unpinned_at = response.body.index("Newer doc")
    assert pinned_at < unpinned_at, "pinned doc should render before the more recent unpinned doc"
  end

  test "pinned docs stay visible even when older than the date filter" do
    travel_to 60.days.ago do
      @old = @alice.documents.create!(body: "# Old but pinned", pinned: true)
    end

    sign_in_as @alice
    get documents_path(since: "7d")

    assert_response :success
    assert_includes response.body, "Old but pinned"
  end

  test "create yields a blank doc and redirects to edit" do
    sign_in_as @alice
    assert_difference -> { @alice.documents.count }, 1 do
      post documents_path
    end
    assert_redirected_to edit_document_path(@alice.documents.order(:created_at).last)
  end

  test "edit starts in rendered preview mode" do
    @doc.update!(body: "# Read first\n\nThen edit when needed.")

    sign_in_as @alice
    get edit_document_path(@doc)

    assert_response :success
    assert_select "[data-editor-initial-preview-value=?]", "true"
    assert_select "button[aria-label=?][aria-pressed=?]", "Edit document", "true"
    assert_select ".preview-host h1", /Read first/
    assert_select ".preview-host p", /Then edit when needed/
  end

  test "blank documents start in edit mode" do
    blank = @alice.documents.create!(body: "")

    sign_in_as @alice
    get edit_document_path(blank)

    assert_response :success
    assert_select "[data-editor-initial-preview-value=?]", "false"
    assert_select "button[aria-label=?][aria-pressed=?]", "Preview document", "false"
  end

  test "update succeeds and returns 204 for autosave" do
    sign_in_as @alice
    patch document_path(@doc), params: { document: { body: "# Updated" } }
    assert_response :no_content
    assert_equal "Updated", @doc.reload.title
  end

  test "cross-user edit returns 404 (no IDOR)" do
    bobs_doc = @bob.documents.create!(body: "Bob")
    sign_in_as @alice
    get edit_document_path(bobs_doc)
    assert_response :not_found
  end

  test "cross-user update returns 404" do
    bobs_doc = @bob.documents.create!(body: "Bob")
    sign_in_as @alice
    patch document_path(bobs_doc), params: { document: { body: "hijacked" } }
    assert_response :not_found
    assert_equal "Bob", bobs_doc.reload.body
  end

  test "cross-user destroy returns 404" do
    bobs_doc = @bob.documents.create!(body: "Bob")
    sign_in_as @alice
    delete document_path(bobs_doc)
    assert_response :not_found
    assert Document.exists?(bobs_doc.id)
  end

  test "destroy on own doc redirects to index" do
    sign_in_as @alice
    delete document_path(@doc)
    assert_redirected_to documents_path
    assert_not Document.exists?(@doc.id)
  end

  test "preview renders supplied body without saving" do
    sign_in_as @alice
    post preview_document_path(@doc), params: { body: "# Live preview" }
    assert_response :success
    # commonmarker GFM may inject an anchor link inside the heading tag;
    # just assert the heading text and tag are present.
    assert_match %r{<h1[^>]*>.*Live preview.*</h1>}m, response.body
    assert_equal "# Alice doc", @doc.reload.body  # untouched
  end

  test "title param in document_params is ignored — title derives from body" do
    sign_in_as @alice
    patch document_path(@doc), params: { document: { body: "# Real title", title: "Spoofed" } }
    @doc.reload
    assert_equal "Real title", @doc.title
  end

  test "tags filter is owner-scoped" do
    @alice.documents.create!(body: "x", tags_text: "claude")
    @bob.documents.create!(body: "y", tags_text: "claude")
    sign_in_as @alice
    get documents_path(tag: "claude", since: "all")
    assert_response :success
    # Alice sees her tagged doc but not Bob's.
    bobs = @bob.documents.with_tag("claude").first
    assert_not_includes response.body, bobs.public_token
  end
end
