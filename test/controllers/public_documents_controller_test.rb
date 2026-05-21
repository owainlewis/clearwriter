require "test_helper"

class PublicDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice  = users(:alice)
    @public = @alice.documents.create!(body: "# Public\nshared", is_public: true)
    @private = @alice.documents.create!(body: "# Private")
  end

  test "GET /d/:token of a public doc renders HTML" do
    get public_document_path(@public.public_token)
    assert_response :success
    assert_match %r{<h1[^>]*>.*Public.*</h1>}m, response.body
  end

  test "GET /d/:token.md returns raw markdown with text/markdown content type" do
    get public_document_path(@public.public_token, format: :md)
    assert_response :success
    assert_equal "text/markdown; charset=utf-8", response.media_type + "; charset=utf-8"
    assert_equal @public.body, response.body
  end

  test "private doc returns 404 (not 403) — no existence leak" do
    get public_document_path(@private.public_token)
    assert_response :not_found
    get public_document_path(@private.public_token, format: :md)
    assert_response :not_found
  end

  test "unknown token returns 404" do
    get public_document_path("nonexistenttokenfornone")
    assert_response :not_found
  end

  test "no auth required" do
    # Confirm we genuinely reach the public route without being bounced to /sign_in.
    get public_document_path(@public.public_token)
    assert_response :success
  end
end
