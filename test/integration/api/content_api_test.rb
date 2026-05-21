require "test_helper"

class Api::ContentApiTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_token = ApiToken.create_for_user!(@alice).raw_token
    @bob_token   = ApiToken.create_for_user!(@bob).raw_token
    @doc = @alice.documents.create!(body: "# Hello\n\nbody\n")
  end

  def auth_headers(token = @alice_token)
    { "Authorization" => "Bearer #{token}" }
  end

  test "GET content returns text/markdown with the body byte-equal" do
    get "/api/v1/documents/#{@doc.public_token}/content", headers: auth_headers
    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_equal @doc.body, response.body
  end

  test "PUT content with raw markdown body replaces and round-trips byte-equal" do
    payload = "# New title\n\nrich utf-8 ✨ — em dash, “smart quotes”, emoji 🚀\n"
    # dup before passing — Rack integration test may mutate encoding in place.
    put "/api/v1/documents/#{@doc.public_token}/content",
        headers: auth_headers.merge("Content-Type" => "text/markdown"),
        params: payload.dup
    assert_response :no_content

    # Byte-identical round trip is the contract — encoding labels can vary
    # depending on adapter / transport.
    assert_equal payload.b, @doc.reload.body.b
    assert_equal payload.bytesize, @doc.body.bytesize

    get "/api/v1/documents/#{@doc.public_token}/content", headers: auth_headers
    assert_equal payload.b, response.body.b
    assert_equal payload.bytesize, response.body.bytesize
  end

  test "cross-user GET content → 404 text/plain (not JSON, not 403)" do
    get "/api/v1/documents/#{@doc.public_token}/content", headers: { "Authorization" => "Bearer #{@bob_token}" }
    assert_response :not_found
    assert_match %r{\Atext/plain}, response.content_type
  end

  test "cross-user PUT content → 404 and doc unchanged" do
    put "/api/v1/documents/#{@doc.public_token}/content",
        headers: { "Authorization" => "Bearer #{@bob_token}", "Content-Type" => "text/markdown" },
        params: "evil"
    assert_response :not_found
    assert_equal "# Hello\n\nbody\n", @doc.reload.body
  end

  test "missing token on content endpoint → 401 text/plain (readable in curl)" do
    get "/api/v1/documents/#{@doc.public_token}/content"
    assert_response :unauthorized
    assert_match %r{\Atext/plain}, response.content_type
  end
end
