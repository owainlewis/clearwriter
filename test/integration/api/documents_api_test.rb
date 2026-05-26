require "test_helper"

class Api::DocumentsApiTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_token = ApiToken.create_for_user!(@alice).raw_token
    @bob_token   = ApiToken.create_for_user!(@bob).raw_token
    @doc = @alice.documents.create!(body: "# Alice doc", tags_text: "onboarding")
  end

  def auth_headers(token = @alice_token)
    { "Authorization" => "Bearer #{token}" }
  end

  test "no token → 401 JSON" do
    get "/api/v1/documents"
    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "invalid_token", body["error"]
  end

  test "garbage token → 401" do
    get "/api/v1/documents", headers: { "Authorization" => "Bearer pair_garbage" }
    assert_response :unauthorized
  end

  test "GET /api/v1/documents lists own docs" do
    @bob.documents.create!(body: "bobs")
    get "/api/v1/documents", headers: auth_headers
    assert_response :success
    list = JSON.parse(response.body)
    assert_equal 1, list.size
    assert_equal @doc.public_token, list[0]["id"]
  end

  test "GET /api/v1/documents filters by tag" do
    @alice.documents.create!(body: "x", tags_text: "claude")
    get "/api/v1/documents", params: { tag: "onboarding" }, headers: auth_headers
    assert_equal 1, JSON.parse(response.body).size
  end

  test "GET /api/v1/documents?q= searches title and body" do
    @alice.documents.create!(body: "# Billing\nwebhook retry logic")
    @alice.documents.create!(body: "# Unrelated note")

    get "/api/v1/documents", params: { q: "webhook" }, headers: auth_headers
    results = JSON.parse(response.body)
    assert_equal 1, results.size
    assert_equal "Billing", results[0]["title"]
  end

  test "search is scoped to the current user" do
    @bob.documents.create!(body: "# Bob secret webhook")
    get "/api/v1/documents", params: { q: "webhook" }, headers: auth_headers
    assert_equal 0, JSON.parse(response.body).size
  end

  test "POST /api/v1/documents creates" do
    assert_difference -> { @alice.documents.count }, 1 do
      post "/api/v1/documents",
           params: { body: "# Created via API", tags: [ "via-api" ] }.to_json,
           headers: auth_headers.merge("Content-Type" => "application/json")
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Created via API", body["title"]
    assert_equal [ "via-api" ], body["tags"]
  end

  test "API rejects spoofed title — derived from body" do
    post "/api/v1/documents",
         params: { body: "# Real", title: "Spoofed" }.to_json,
         headers: auth_headers.merge("Content-Type" => "application/json")
    assert_response :created
    assert_equal "Real", JSON.parse(response.body)["title"]
  end

  test "cross-user document → 404 JSON" do
    get "/api/v1/documents/#{@doc.public_token}", headers: { "Authorization" => "Bearer #{@bob_token}" }
    assert_response :not_found
    assert_equal "not_found", JSON.parse(response.body)["error"]
  end

  test "DELETE removes the doc" do
    assert_difference -> { Document.count }, -1 do
      delete "/api/v1/documents/#{@doc.public_token}", headers: auth_headers
    end
    assert_response :no_content
  end

  test "public_url is only present when doc is_public" do
    get "/api/v1/documents/#{@doc.public_token}", headers: auth_headers
    assert_nil JSON.parse(response.body)["public_url"]

    @doc.update!(is_public: true)
    get "/api/v1/documents/#{@doc.public_token}", headers: auth_headers
    assert JSON.parse(response.body)["public_url"].present?
  end

  test "touch_last_used: timestamp updates after a request" do
    record = ApiToken.where(user: @alice).order(:created_at).last
    assert_nil record.last_used_at
    get "/api/v1/documents", headers: auth_headers
    assert record.reload.last_used_at
  end
end
