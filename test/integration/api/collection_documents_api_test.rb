require "test_helper"

# The agent publish path: an agent POSTs into a collection, either attaching
# an existing doc or creating one from markdown in a single call.
class Api::CollectionDocumentsApiTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_token = ApiToken.create_for_user!(@alice).raw_token
    @bob_token   = ApiToken.create_for_user!(@bob).raw_token
    @collection = @alice.collections.create!(name: "YouTube video")
  end

  def auth_headers(token = @alice_token)
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  test "POST with body creates a doc and attaches it (publish)" do
    assert_difference [ -> { @alice.documents.count }, -> { @collection.collection_documents.count } ], 1 do
      post "/api/v1/collections/#{@collection.public_token}/documents",
           params: { body: "# Research notes\nfindings", tags: [ "research" ] }.to_json,
           headers: auth_headers
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Research notes", body["title"]
    assert_equal [ "research" ], body["tags"]
    assert_equal 1, @collection.reload.documents.size
  end

  test "POST with document_id attaches an existing doc" do
    doc = @alice.documents.create!(body: "# Existing")
    assert_difference -> { @alice.documents.count }, 0 do
      post "/api/v1/collections/#{@collection.public_token}/documents",
           params: { document_id: doc.public_token }.to_json,
           headers: auth_headers
    end
    assert_response :created
    assert_equal [ doc ], @collection.reload.documents.to_a
  end

  test "re-attaching the same doc is idempotent" do
    doc = @alice.documents.create!(body: "# Existing")
    2.times do
      post "/api/v1/collections/#{@collection.public_token}/documents",
           params: { document_id: doc.public_token }.to_json,
           headers: auth_headers
    end
    assert_equal 1, @collection.reload.collection_documents.count
  end

  test "POST with neither body nor document_id → 422" do
    post "/api/v1/collections/#{@collection.public_token}/documents",
         params: {}.to_json,
         headers: auth_headers
    assert_response :unprocessable_entity
    assert_equal "invalid", JSON.parse(response.body)["error"]
  end

  test "cannot attach another user's doc" do
    bobs_doc = @bob.documents.create!(body: "Bob")
    post "/api/v1/collections/#{@collection.public_token}/documents",
         params: { document_id: bobs_doc.public_token }.to_json,
         headers: auth_headers
    assert_response :not_found
    assert_empty @collection.reload.documents
  end

  test "cannot publish into another user's collection" do
    post "/api/v1/collections/#{@collection.public_token}/documents",
         params: { body: "# Sneaky" }.to_json,
         headers: auth_headers(@bob_token)
    assert_response :not_found
  end

  test "DELETE detaches a doc without deleting it" do
    doc = @alice.documents.create!(body: "# Attached")
    @collection.add_document(doc)
    assert_difference -> { Document.count }, 0 do
      delete "/api/v1/collections/#{@collection.public_token}/documents/#{doc.public_token}",
             headers: auth_headers
    end
    assert_response :no_content
    assert_empty @collection.reload.documents
  end
end
