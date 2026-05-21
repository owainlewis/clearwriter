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

  test "create yields a blank doc and redirects to edit" do
    sign_in_as @alice
    assert_difference -> { @alice.documents.count }, 1 do
      post documents_path
    end
    assert_redirected_to edit_document_path(@alice.documents.order(:created_at).last)
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
