require "test_helper"

class Api::CollectionsApiTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_token = ApiToken.create_for_user!(@alice).raw_token
    @bob_token   = ApiToken.create_for_user!(@bob).raw_token
    @collection = @alice.collections.create!(name: "YouTube video")
  end

  def auth_headers(token = @alice_token)
    { "Authorization" => "Bearer #{token}" }
  end

  test "no token → 401" do
    get "/api/v1/collections"
    assert_response :unauthorized
  end

  test "GET /api/v1/collections lists own collections with counts" do
    @bob.collections.create!(name: "Bobs")
    @collection.add_document(@alice.documents.create!(body: "# A"))

    get "/api/v1/collections", headers: auth_headers
    assert_response :success
    list = JSON.parse(response.body)
    assert_equal 1, list.size
    assert_equal @collection.public_token, list[0]["id"]
    assert_equal 1, list[0]["document_count"]
  end

  test "POST creates a collection" do
    assert_difference -> { @alice.collections.count }, 1 do
      post "/api/v1/collections",
           params: { name: "Photos" }.to_json,
           headers: auth_headers.merge("Content-Type" => "application/json")
    end
    assert_response :created
    assert_equal "Photos", JSON.parse(response.body)["name"]
  end

  test "GET show includes member documents" do
    doc = @alice.documents.create!(body: "# In bundle")
    @collection.add_document(doc)

    get "/api/v1/collections/#{@collection.public_token}", headers: auth_headers
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["documents"].size
    assert_equal doc.public_token, body["documents"][0]["id"]
  end

  test "PATCH renames" do
    patch "/api/v1/collections/#{@collection.public_token}",
          params: { name: "Renamed" }.to_json,
          headers: auth_headers.merge("Content-Type" => "application/json")
    assert_response :success
    assert_equal "Renamed", @collection.reload.name
  end

  test "DELETE removes the collection" do
    assert_difference -> { Collection.count }, -1 do
      delete "/api/v1/collections/#{@collection.public_token}", headers: auth_headers
    end
    assert_response :no_content
  end

  test "cross-user collection → 404" do
    get "/api/v1/collections/#{@collection.public_token}",
        headers: { "Authorization" => "Bearer #{@bob_token}" }
    assert_response :not_found
  end
end
